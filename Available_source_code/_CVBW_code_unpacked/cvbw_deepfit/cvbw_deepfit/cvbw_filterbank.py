"""
cvbw_filterbank.py
==================
Differentiable Farrow-structure Continuously Variable Bandwidth (CVBW)
analysis / synthesis filter bank.

Design mirrors the Farrow-differentiator CVBW filter (Indrakanti et al., AEU 2018):
a fixed linear-phase prototype low-pass filter sandwiched between two
sample-rate-conversion (SRC) interpolators built from order-N Lagrangian
fractional-delay (FD) sub-filters. The novelty here (contribution #2 in the
manuscript) is that the bandwidth factor `rf` is a *differentiable* tensor, so
gradients flow through the Farrow sub-filter coefficients:

        c_{n,k} = ((-1)^k / k!) * h_{k,N}(n)

The interpolator applies a Taylor/Lagrange expansion around each fractional
sample position; the fractional delay `d` is a smooth function of `rf`, giving
d(output)/d(rf) in closed form via autograd.

This is a research reference implementation: clarity over raw throughput.
"""

from __future__ import annotations
import math
import torch
import torch.nn as nn
import torch.nn.functional as F


# ----------------------------------------------------------------------------
# Fixed prototype low-pass (Parks-McClellan-like). We approximate with a
# windowed-sinc here so the module is self-contained; swap in a remez design
# (scipy.signal.remez) for the exact specs used in the paper:
#   passband ripple 0.05 dB, stopband attn 80 dB, transition width 0.1625.
# ----------------------------------------------------------------------------
def prototype_lowpass(num_taps: int = 63, cutoff: float = 0.12) -> torch.Tensor:
    n = torch.arange(num_taps) - (num_taps - 1) / 2.0
    h = 2 * cutoff * torch.sinc(2 * cutoff * n)           # ideal LP
    win = torch.hamming_window(num_taps, periodic=False)  # window it
    h = h * win
    h = h / h.sum()                                       # unity DC gain
    return h


# ----------------------------------------------------------------------------
# Lagrangian fractional-delay sub-filter coefficients for order N (default 4).
# Returns tensor [N+1, N+1] mapping polynomial power k -> impulse-response taps.
# These are the Farrow sub-filter coefficients C_k(z) (Table 2 in the paper).
# ----------------------------------------------------------------------------
def farrow_subfilters(N: int = 4) -> torch.Tensor:
    # Symbolic Lagrange interpolation, evaluated as a Vandermonde solve.
    # Node positions for a symmetric FD filter of order N: 0..N centred at N/2.
    nodes = torch.arange(N + 1, dtype=torch.float64) - N / 2.0
    # Vandermonde of the nodes: V[i, k] = nodes[i]^k
    V = torch.stack([nodes ** k for k in range(N + 1)], dim=1)  # [N+1, N+1]
    Vinv = torch.linalg.inv(V)                                  # [N+1, N+1]
    # Row k of Vinv gives the polynomial coefficients that pick out d^k.
    # Farrow sub-filter C_k = Vinv[k, :]  (tap index -> weight).
    return Vinv.to(torch.float32)                               # [k, tap]


def eval_farrow(C: torch.Tensor, d: torch.Tensor) -> torch.Tensor:
    """
    Evaluate the Farrow structure at fractional delay d (scalar tensor or vec).
    C: [K, taps]. Returns FD-filter taps [taps] (or [len(d), taps]).
    tap_weight(tap) = sum_k C[k, tap] * d^k
    """
    K = C.shape[0]
    d = d.reshape(-1)                                    # [D]
    powers = torch.stack([d ** k for k in range(K)], 1)  # [D, K]
    taps = powers @ C                                    # [D, taps]
    return taps


# ----------------------------------------------------------------------------
# Differentiable SRC interpolator: resamples x by ratio `rf` using the Farrow
# structure. rf < 1 narrows bandwidth (down-then-up), rf > 1 widens it.
# ----------------------------------------------------------------------------
class FarrowSRC(nn.Module):
    def __init__(self, N: int = 4):
        super().__init__()
        self.N = N
        self.register_buffer("C", farrow_subfilters(N))   # fixed sub-filters

    def forward(self, x: torch.Tensor, rf: torch.Tensor) -> torch.Tensor:
        """
        x:  [B, T] real signal.
        rf: scalar tensor (differentiable) - resample ratio.
        Returns resampled signal [B, T'] with T' ~ T / rf.
        """
        B, T = x.shape
        step = rf                                        # output-sample spacing
        # Output positions in input-sample coordinates.
        n_out = torch.arange(0, T, 1.0, device=x.device)  # keep length stable
        pos = n_out * step
        base = torch.floor(pos).long()                    # nearest left index k
        d = (pos - base.float()) - 0.5                     # frac in [-0.5, 0.5]
        # Farrow taps for every output position: [len, taps]
        taps = eval_farrow(self.C, d)                      # [len, N+1]
        # Gather the N+1 input samples around each base index.
        offs = torch.arange(-(self.N // 2), self.N // 2 + 1, device=x.device)
        idx = base.unsqueeze(1) + offs.unsqueeze(0)        # [len, N+1]
        idx = idx.clamp(0, T - 1)
        gathered = x[:, idx]                               # [B, len, N+1]
        out = (gathered * taps.unsqueeze(0)).sum(-1)       # [B, len]
        return out


# ----------------------------------------------------------------------------
# Full CVBW band: down-sample (X-to-Y) -> fixed filter -> up-sample (Y-to-X).
# The band's centre frequency is set by a complex heterodyne (frequency shift).
# ----------------------------------------------------------------------------
class CVBWBand(nn.Module):
    def __init__(self, num_taps: int = 63, N: int = 4):
        super().__init__()
        self.src_down = FarrowSRC(N)
        self.src_up = FarrowSRC(N)
        self.register_buffer("proto", prototype_lowpass(num_taps))
        self.pad = num_taps // 2

    def _fixed_filter(self, x):
        w = self.proto.view(1, 1, -1)
        return F.conv1d(x.unsqueeze(1), w, padding=self.pad).squeeze(1)

    def forward(self, x, rf, fc):
        """
        x:  [B, T] real.  rf: scalar (bandwidth factor).  fc: centre freq (norm).
        Returns the band-limited, frequency-shifted sub-band [B, T].
        """
        B, T = x.shape
        # heterodyne to baseband
        t = torch.arange(T, device=x.device).float()
        lo = torch.exp(-1j * 2 * math.pi * fc * t)
        xb = (x * lo).real                                # shift band to DC (real part proxy)
        y = self.src_down(xb, rf)                         # narrow
        y = self._fixed_filter(y)
        y = self.src_up(y, 1.0 / rf)                      # restore rate
        y = y[:, :T]
        if y.shape[1] < T:
            y = F.pad(y, (0, T - y.shape[1]))
        return y


# ----------------------------------------------------------------------------
# The analysis bank: B parallel CVBW bands, each with its own differentiable
# rf and centre frequency. Returns sub-band tensor [B, bands, T].
# ----------------------------------------------------------------------------
class CVBWAnalysisBank(nn.Module):
    def __init__(self, n_bands: int = 6, num_taps: int = 63, N: int = 4,
                 sample_rate: int = 16000):
        super().__init__()
        self.n_bands = n_bands
        self.band = CVBWBand(num_taps, N)
        # Differentiable per-band bandwidth factors (contribution #2).
        # Init near 1.0 (no change) then let training move them.
        self.rf = nn.Parameter(torch.ones(n_bands))
        # Mel-spaced centre frequencies (normalised 0..0.5).
        fcs = torch.linspace(0.02, 0.45, n_bands)
        self.register_buffer("fc", fcs)

    def forward(self, x):
        bands = []
        for b in range(self.n_bands):
            rf_b = F.softplus(self.rf[b]) + 0.1           # keep rf > 0
            bands.append(self.band(x, rf_b, self.fc[b]))
        return torch.stack(bands, dim=1)                  # [B, bands, T]


class CVBWSynthesis(nn.Module):
    """Recombine masked sub-bands, applying per-band audiogram-matching gains."""
    def __init__(self, n_bands: int = 6):
        super().__init__()
        # Sub-band fitting gains y_I (contribution #1: applied to masked bands).
        self.gain = nn.Parameter(torch.zeros(n_bands))   # dB, learned per audiogram head

    def forward(self, sub_bands, fit_gain_db=None):
        # sub_bands: [B, bands, T]. fit_gain_db: [B, bands] or None.
        if fit_gain_db is None:
            fit_gain_db = self.gain.unsqueeze(0)          # broadcast
        lin = 10 ** (fit_gain_db / 20.0)                  # dB -> linear
        y = (sub_bands * lin.unsqueeze(-1)).sum(dim=1)    # [B, T]
        return y


if __name__ == "__main__":
    torch.manual_seed(0)
    x = torch.randn(2, 8000)
    bank = CVBWAnalysisBank(n_bands=6)
    syn = CVBWSynthesis(n_bands=6)
    sb = bank(x)
    out = syn(sb)
    print("sub-bands:", tuple(sb.shape), "-> synth:", tuple(out.shape))
    # confirm gradient flows to differentiable bandwidth factor
    out.sum().backward()
    print("grad on rf (bandwidth factor):", bank.rf.grad.abs().sum().item())
