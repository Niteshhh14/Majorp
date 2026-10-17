"""
mask_estimator.py
=================
Audiogram-conditioned, causal Temporal Convolutional Network (TCN) that
predicts a complex-valued ratio mask per sub-band.

Contribution #3: the listener's audiogram modulates every residual block via
Feature-wise Linear Modulation (FiLM). A single trained model therefore adapts
its suppression aggressiveness from conservative (normal hearing) to maximal
(cochlear implant) -- directly targeting the sign-flip in SRT benefit reported
in the reference literature.

Causality: all convolutions are left-padded only, so no future samples leak in.
This is what keeps algorithmic look-ahead near zero (RQ2 / latency).
"""

from __future__ import annotations
import torch
import torch.nn as nn
import torch.nn.functional as F


class AudiogramEncoder(nn.Module):
    """
    Maps a listener descriptor to a conditioning embedding.
    Input vector layout (example, 11-D):
      [PTA_L@0.5k, 1k, 2k, 4k, PTA_R@0.5k, 1k, 2k, 4k, dev_HA, dev_CI, aided]
    Thresholds are in dB HL, normalised by /120.
    """
    def __init__(self, in_dim: int = 11, emb_dim: int = 32):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, 64), nn.ReLU(),
            nn.Linear(64, emb_dim), nn.ReLU(),
        )

    def forward(self, audiogram):          # [B, in_dim]
        return self.net(audiogram)         # [B, emb_dim]


class FiLM(nn.Module):
    """Produces per-channel scale (gamma) and shift (beta) from the embedding."""
    def __init__(self, emb_dim: int, channels: int):
        super().__init__()
        self.to_gamma = nn.Linear(emb_dim, channels)
        self.to_beta = nn.Linear(emb_dim, channels)

    def forward(self, feat, emb):          # feat [B,C,T], emb [B,E]
        gamma = self.to_gamma(emb).unsqueeze(-1)   # [B,C,1]
        beta = self.to_beta(emb).unsqueeze(-1)
        return feat * (1 + gamma) + beta


class CausalResBlock(nn.Module):
    def __init__(self, channels, emb_dim, kernel=3, dilation=1):
        super().__init__()
        self.pad = (kernel - 1) * dilation           # left pad only -> causal
        self.conv1 = nn.Conv1d(channels, channels, kernel, dilation=dilation)
        self.conv2 = nn.Conv1d(channels, channels, 1)  # pointwise mix
        self.norm = nn.GroupNorm(1, channels)
        self.film = FiLM(emb_dim, channels)

    def forward(self, x, emb):
        y = F.pad(x, (self.pad, 0))
        y = F.relu(self.conv1(y))
        y = self.film(y, emb)                # audiogram conditioning
        y = F.relu(self.conv2(y))
        y = self.norm(y)
        return x + y                         # residual


class MaskEstimator(nn.Module):
    """
    Predicts a complex ratio mask (2 channels: real, imag) per sub-band.
    Works on the sub-band magnitude/feature tensor from the CVBW bank.
    """
    def __init__(self, n_bands: int = 6, channels: int = 64, emb_dim: int = 32,
                 n_blocks: int = 6, in_features: int = 1):
        super().__init__()
        self.audio_enc = AudiogramEncoder(emb_dim=emb_dim)
        self.in_proj = nn.Conv1d(n_bands * in_features, channels, 1)
        dilations = [2 ** (i % 4) for i in range(n_blocks)]
        self.blocks = nn.ModuleList(
            [CausalResBlock(channels, emb_dim, dilation=d) for d in dilations]
        )
        # Output: 2 (re,im) mask coefficients per band.
        self.out_proj = nn.Conv1d(channels, n_bands * 2, 1)
        self.n_bands = n_bands

    def forward(self, sub_feats, audiogram):
        """
        sub_feats: [B, bands, T]  (e.g. |sub-band| envelope, or the bands directly)
        audiogram: [B, 11]
        returns mask_re, mask_im each [B, bands, T]
        """
        emb = self.audio_enc(audiogram)              # [B, E]
        h = self.in_proj(sub_feats)                  # [B, C, T]
        for blk in self.blocks:
            h = blk(h, emb)
        m = self.out_proj(h)                         # [B, 2*bands, T]
        m = torch.tanh(m)                            # bounded mask
        mre, mim = m[:, :self.n_bands], m[:, self.n_bands:]
        return mre, mim


if __name__ == "__main__":
    torch.manual_seed(0)
    sub = torch.randn(2, 6, 4000)
    aud = torch.rand(2, 11)
    est = MaskEstimator(n_bands=6)
    mre, mim = est(sub, aud)
    print("mask:", tuple(mre.shape), tuple(mim.shape))
    n_params = sum(p.numel() for p in est.parameters())
    print(f"params: {n_params/1e3:.1f}k (budget target <= 250k)")
    # verify audiogram actually changes the mask (conditioning is live)
    aud2 = aud.clone(); aud2[:, :4] = 1.0            # simulate profound HL
    mre2, _ = est(sub, aud2)
    print("mask delta from audiogram change:", (mre2 - mre).abs().mean().item())
