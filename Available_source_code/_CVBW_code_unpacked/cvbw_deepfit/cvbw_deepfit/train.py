"""
train.py
========
Training skeleton for CVBW-DeepFit.

Run a smoke test on synthetic data:
    python -m cvbw_deepfit.train --smoke

For real training, replace `SyntheticNoisyDataset` with a loader that yields
(noisy, clean, audiogram, target_fit_db) from your mixed VoxCeleb2/WHAM! corpus
per manuscript Section 6.8, and wire in the trained HI-pMOS network.
"""

from __future__ import annotations
import argparse
import torch
from torch.utils.data import Dataset, DataLoader

from cvbw_deepfit.model import CVBWDeepFit
from cvbw_deepfit.losses import total_loss, LossWeights


class SyntheticNoisyDataset(Dataset):
    """Placeholder: clean tone + noise at a sampled SNR, random audiogram."""
    def __init__(self, n=256, T=8000, sr=16000):
        self.n, self.T, self.sr = n, T, sr

    def __len__(self):
        return self.n

    def __getitem__(self, i):
        t = torch.arange(self.T) / self.sr
        f0 = 120 + 200 * torch.rand(1).item()
        clean = torch.sin(2 * torch.pi * f0 * t) * 0.5
        snr_db = torch.empty(1).normal_(8, 7).item()          # realistic SNR dist
        noise = torch.randn(self.T)
        g = 10 ** (-snr_db / 20)
        noisy = clean + g * noise / (noise.std() + 1e-8) * clean.std()
        audiogram = torch.rand(11)                            # sampled listener
        audiogram[:8] *= (0.2 + 0.8 * torch.rand(1))          # varied severity
        target_fit_db = audiogram[:6] * 40                    # toy prescription
        return noisy, clean, audiogram, target_fit_db


def train(smoke=False, epochs=1, bs=8, lr=3e-4, device="cpu"):
    ds = SyntheticNoisyDataset(n=32 if smoke else 20000)
    dl = DataLoader(ds, batch_size=bs, shuffle=True)
    model = CVBWDeepFit(n_bands=6).to(device)
    opt = torch.optim.Adam(model.parameters(), lr=lr)
    w = LossWeights()

    model.train()
    for ep in range(epochs):
        for step, (noisy, clean, aud, tgt) in enumerate(dl):
            noisy, clean = noisy.to(device), clean.to(device)
            aud, tgt = aud.to(device), tgt.to(device)
            y_hat, aux = model(noisy, aud)
            loss, parts = total_loss(y_hat, clean, aux, model, tgt, w=w)
            opt.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            opt.step()
            if step % 2 == 0:
                print(f"ep{ep} step{step} " +
                      " ".join(f"{k}={v:.3f}" for k, v in parts.items()))
            if smoke and step >= 2:
                print("smoke test OK")
                return model
    return model


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--smoke", action="store_true")
    ap.add_argument("--epochs", type=int, default=1)
    args = ap.parse_args()
    train(smoke=args.smoke, epochs=args.epochs)
