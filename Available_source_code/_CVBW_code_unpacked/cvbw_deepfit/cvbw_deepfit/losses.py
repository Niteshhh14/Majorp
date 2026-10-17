"""
losses.py
=========
Multi-objective training loss (manuscript Section 6.4).

    L = w1*L_cIRM   + w2*L_HIpMOS + w3*L_HASPI
      + w4*L_match  + w5*L_hw     + w6*L_TFS

L_HIpMOS and L_HASPI wrap external estimators. Here we provide differentiable
stand-ins (SI-SDR and an envelope-correlation proxy) so the pipeline is
runnable end-to-end; replace with the trained HI-pMOS network and a HASPI
surrogate for real experiments.

The weights w1..w6 are NOT hand-tuned in the paper -- they are points on a
Pareto front discovered during multi-objective search. `LossWeights` just
holds a chosen operating point.
"""

from __future__ import annotations
from dataclasses import dataclass
import torch
import torch.nn.functional as F


@dataclass
class LossWeights:
    cirm: float = 1.0
    hipmos: float = 0.5
    haspi: float = 0.5
    match: float = 0.3
    hw: float = 0.1
    tfs: float = 0.2


def si_sdr(est, ref, eps=1e-8):
    ref = ref - ref.mean(-1, keepdim=True)
    est = est - est.mean(-1, keepdim=True)
    alpha = (est * ref).sum(-1, keepdim=True) / (ref.pow(2).sum(-1, keepdim=True) + eps)
    proj = alpha * ref
    noise = est - proj
    ratio = (proj.pow(2).sum(-1) + eps) / (noise.pow(2).sum(-1) + eps)
    return 10 * torch.log10(ratio + eps)


def envelope_corr(est, ref, eps=1e-8):
    """Cheap STOI-like envelope correlation proxy (HASPI stand-in)."""
    e = est.abs(); r = ref.abs()
    e = e - e.mean(-1, keepdim=True); r = r - r.mean(-1, keepdim=True)
    num = (e * r).sum(-1)
    den = torch.sqrt(e.pow(2).sum(-1) * r.pow(2).sum(-1) + eps)
    return num / (den + eps)


def tfs_penalty(mask_im):
    """Discourage large imaginary-mask excursions that smear fine structure."""
    return mask_im.pow(2).mean()


def hw_penalty(model):
    """
    Differentiable surrogate for signed-power-of-two term count: encourage the
    fixed prototype + Farrow sub-filters toward sparse, low-precision-friendly
    coefficients (L1 on the trainable filter params). Real quantization happens
    post-hoc via MOABC + SID-CSE (see quantize.py).
    """
    reg = 0.0
    for name, p in model.named_parameters():
        if "rf" in name or "gain" in name or "proto" in name:
            reg = reg + p.abs().mean()
    return reg


def match_loss(fit_db, target_db):
    """Least-squares audiogram matching error over bands (manuscript Eq. 18)."""
    return F.mse_loss(fit_db, target_db)


def total_loss(y_hat, clean, aux, model, target_fit_db, hipmos_net=None,
               w: LossWeights = LossWeights()):
    T = min(y_hat.shape[-1], clean.shape[-1])
    y_hat, clean = y_hat[..., :T], clean[..., :T]

    L_cirm = -si_sdr(y_hat, clean).mean()                 # maximise SI-SDR
    L_haspi = -envelope_corr(y_hat, clean).mean()         # maximise intelligibility
    if hipmos_net is not None:
        L_hipmos = -hipmos_net(y_hat, clean).mean()
    else:
        L_hipmos = -si_sdr(y_hat, clean).mean() * 0.5     # stand-in
    L_match = match_loss(aux["fit_db"], target_fit_db)
    L_hw = hw_penalty(model)
    L_tfs = tfs_penalty(aux["mask_im"])

    total = (w.cirm * L_cirm + w.hipmos * L_hipmos + w.haspi * L_haspi
             + w.match * L_match + w.hw * L_hw + w.tfs * L_tfs)

    return total, {
        "cirm": L_cirm.item(), "hipmos": L_hipmos.item(), "haspi": L_haspi.item(),
        "match": L_match.item(),
        "hw": float(L_hw.detach()) if hasattr(L_hw, "detach") else float(L_hw),
        "tfs": L_tfs.item(),
        "total": total.item(),
    }


if __name__ == "__main__":
    from cvbw_deepfit.model import CVBWDeepFit  # run via: python -m cvbw_deepfit.losses
    import torch
    m = CVBWDeepFit(n_bands=6)
    x = torch.randn(2, 8000); clean = torch.randn(2, 8000); aud = torch.rand(2, 11)
    y, aux = m(x, aud)
    tgt = torch.rand(2, 6) * 30
    L, parts = total_loss(y, clean, aux, m, tgt)
    print("loss parts:", {k: round(v, 3) for k, v in parts.items()})
    L.backward()
    print("backward OK")
