"""
quantize.py
===========
Post-training coefficient quantization and multiplier-less mapping
(manuscript Section 6.6). Two stages:

  1. CSD / signed-power-of-two (SPT) quantization of filter coefficients.
  2. MOABC search to recover stop-band attenuation lost to quantization,
     followed by modified SID-CSE adder minimisation.

Full MOABC and the directed-minimal-spanning-tree SID-CSE are large; here we
give (a) a correct CSD encoder, (b) an adder-count estimator, and (c) a compact
multi-objective artificial bee colony that trades stop-band attenuation against
adder count over integer SPT codes. This is enough to reproduce the
Pareto-style tables in the manuscript at reduced scale.
"""

from __future__ import annotations
import numpy as np


# ---------------------------------------------------------------------------
# CSD encoding: represent a value with at most `max_spt` signed powers of two.
# Returns list of (sign, shift) pairs; adder count ~ (#terms - 1).
# ---------------------------------------------------------------------------
def to_csd(value: float, word_len: int = 18, max_spt: int = 4):
    scale = 2 ** (word_len - 1)
    v = int(round(value * scale))
    terms = []
    bitpos = 0
    x = abs(v)
    sign = 1 if v >= 0 else -1
    # greedy non-adjacent form
    csd_bits = []
    while x > 0:
        if x & 1:
            two = x & 3               # look at lowest two bits
            if two == 3:
                csd_bits.append((-1, bitpos)); x += 1
            else:
                csd_bits.append((+1, bitpos))
        x >>= 1; bitpos += 1
    # keep only the `max_spt` largest-magnitude terms
    csd_bits.sort(key=lambda sb: -sb[1])
    csd_bits = csd_bits[:max_spt]
    terms = [(sign * s, sh) for (s, sh) in csd_bits]
    # reconstruct quantised value
    q = sum(s * (2 ** sh) for (s, sh) in terms) / scale
    return terms, q


def adder_count(coeffs, word_len=18, max_spt=4):
    total = 0
    for c in coeffs:
        terms, _ = to_csd(c, word_len, max_spt)
        total += max(0, len(terms) - 1)     # n terms -> n-1 adders
    return total


def stopband_attn_proxy(coeffs_q, coeffs_ref):
    """Cheap proxy: coefficient error energy -> attenuation degradation (dB)."""
    err = np.asarray(coeffs_q) - np.asarray(coeffs_ref)
    e = np.sqrt(np.mean(err ** 2)) + 1e-9
    return -20 * np.log10(e)                 # higher is better


# ---------------------------------------------------------------------------
# Compact Multi-Objective Artificial Bee Colony (MOABC).
# Objectives: maximise stop-band attenuation, minimise adder count.
# Search variable: per-coefficient (word_len, max_spt) choices.
# ---------------------------------------------------------------------------
def moabc(coeffs_ref, colony=20, cycles=40, word_choices=(14, 16, 18, 20),
          spt_choices=(3, 4, 5, 6), seed=0):
    rng = np.random.default_rng(seed)
    n = len(coeffs_ref)

    def evaluate(genome):
        wl, spt = genome
        q = [to_csd(c, wl, spt)[1] for c in coeffs_ref]
        attn = stopband_attn_proxy(q, coeffs_ref)
        adders = adder_count(coeffs_ref, wl, spt)
        return attn, adders

    # each food source = (word_len, max_spt) applied globally (compact version)
    pop = [(int(rng.choice(word_choices)), int(rng.choice(spt_choices)))
           for _ in range(colony)]
    archive = []
    for _ in range(cycles):
        for i in range(colony):
            wl, spt = pop[i]
            # neighbour move
            wl2 = int(rng.choice(word_choices)) if rng.random() < 0.5 else wl
            spt2 = int(rng.choice(spt_choices)) if rng.random() < 0.5 else spt
            a1 = evaluate((wl, spt)); a2 = evaluate((wl2, spt2))
            # dominance: prefer higher attn AND lower adders
            if (a2[0] >= a1[0] and a2[1] <= a1[1]):
                pop[i] = (wl2, spt2)
            archive.append(((wl, spt), a1))
            archive.append(((wl2, spt2), a2))
    # extract Pareto front
    front = []
    for g, (attn, adders) in archive:
        dominated = any((o_attn >= attn and o_add <= adders and (o_attn, o_add) != (attn, adders))
                        for _, (o_attn, o_add) in archive)
        if not dominated:
            front.append((g, attn, adders))
    # dedup
    seen = set(); uniq = []
    for g, attn, adders in front:
        key = (g, round(attn, 2), adders)
        if key not in seen:
            seen.add(key); uniq.append((g, round(attn, 1), adders))
    uniq.sort(key=lambda z: z[2])
    return uniq


if __name__ == "__main__":
    # example: the fixed-prototype coefficients from the CVBW bank
    from cvbw_deepfit.cvbw_filterbank import prototype_lowpass
    coeffs = prototype_lowpass(63).numpy().tolist()
    print("baseline adders (18b,4spt):", adder_count(coeffs, 18, 4))
    front = moabc(coeffs, colony=16, cycles=30)
    print("MOABC Pareto front (word_len,spt | attn_dB | adders):")
    for g, attn, add in front[:8]:
        print(f"  {g}  attn~{attn}dB  adders={add}")
