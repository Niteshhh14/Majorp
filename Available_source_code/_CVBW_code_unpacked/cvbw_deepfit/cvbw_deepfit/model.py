"""
model.py
========
CVBW-DeepFit: the fused model.

Data flow (contribution #1, filter-bank fusion):

    x ->[CVBW analysis bank]-> sub-bands ---------------------+
                                   |                          |
                                   v                          |
                        [MaskEstimator + audiogram]           |
                                   |                          |
                            complex mask                      |
                                   |                          |
              sub-bands (x) mask  <-----------(fuse)----------+
                                   |
                          per-band fitting gains (from audiogram head)
                                   |
                           [CVBW synthesis] -> y_hat

The mask and the audiogram-matching gain live in the SAME sub-band domain and
are merged before a single synthesis pass -- one analysis/synthesis latency,
not two.
"""

from __future__ import annotations
import torch
import torch.nn as nn

from .cvbw_filterbank import CVBWAnalysisBank, CVBWSynthesis
from .mask_estimator import MaskEstimator


class FittingGainHead(nn.Module):
    """
    Maps the audiogram to per-band amplification gains (dB) for audiogram
    matching. Trained under L_match so the summed band response follows the
    prescribed target within +/- 3 dB.
    """
    def __init__(self, n_bands: int, in_dim: int = 11, max_db: float = 40.0):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, 64), nn.ReLU(),
            nn.Linear(64, n_bands)
        )
        self.max_db = max_db

    def forward(self, audiogram):
        return torch.tanh(self.net(audiogram)) * self.max_db     # [B, bands] dB


class CVBWDeepFit(nn.Module):
    def __init__(self, n_bands: int = 6, sample_rate: int = 16000,
                 blend: float = 0.9):
        super().__init__()
        self.bank = CVBWAnalysisBank(n_bands=n_bands, sample_rate=sample_rate)
        self.estimator = MaskEstimator(n_bands=n_bands)
        self.synth = CVBWSynthesis(n_bands=n_bands)
        self.fit_head = FittingGainHead(n_bands)
        self.blend = blend           # 0.9 denoised + 0.1 original (env. awareness)
        self.n_bands = n_bands

    def forward(self, x, audiogram):
        """
        x:         [B, T] noisy waveform
        audiogram: [B, 11]
        returns:   y_hat [B, T], and a dict of intermediates for losses.
        """
        sub = self.bank(x)                       # [B, bands, T]
        mre, mim = self.estimator(sub, audiogram)

        # complex ratio masking on the (real) sub-band; imag part shapes phase
        masked = sub * mre - torch.roll(sub, 1, dims=-1) * mim

        fit_db = self.fit_head(audiogram)        # [B, bands] audiogram matching
        y = self.synth(masked, fit_db)           # [B, T]

        # blend for environmental awareness (Discussion in the manuscript)
        y_hat = self.blend * y + (1 - self.blend) * x[:, :y.shape[1]]

        return y_hat, {"sub": sub, "masked": masked, "fit_db": fit_db,
                       "mask_re": mre, "mask_im": mim}


if __name__ == "__main__":
    torch.manual_seed(0)
    model = CVBWDeepFit(n_bands=6)
    x = torch.randn(2, 8000)
    aud = torch.rand(2, 11)
    y, aux = model(x, aud)
    print("y_hat:", tuple(y.shape))
    total = sum(p.numel() for p in model.parameters())
    print(f"total params: {total/1e3:.1f}k")
    y.sum().backward()
    print("end-to-end backward OK; bank rf grad:",
          model.bank.rf.grad.abs().sum().item())
