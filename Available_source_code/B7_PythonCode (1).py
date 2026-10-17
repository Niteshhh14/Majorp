import os
import torch
import torch.nn as nn
import torch.optim as optim
import librosa
import librosa.display
import soundfile as sf
import numpy as np
import matplotlib.pyplot as plt

from torch.utils.data import Dataset, DataLoader
from pystoi import stoi
from pesq import pesq


# ===============================
# SETTINGS
# ===============================

SR = 16000
DURATION = 1.0
SAMPLES = int(SR * DURATION)

os.makedirs("plots", exist_ok=True)
os.makedirs("outputs", exist_ok=True)


# ===============================
# DATASET
# ===============================

class HearingDataset(Dataset):

    def __init__(self, clean_folder, noisy_folder):

        self.clean_files = sorted([
            os.path.join(clean_folder, f)
            for f in os.listdir(clean_folder)
            if f.endswith(".wav")
        ])

        self.noisy_files = sorted([
            os.path.join(noisy_folder, f)
            for f in os.listdir(noisy_folder)
            if f.endswith(".wav")
        ])

        assert len(self.clean_files) == len(self.noisy_files)

    def __len__(self):
        return len(self.clean_files)

    def __getitem__(self, idx):

        clean, _ = librosa.load(self.clean_files[idx], sr=SR)
        noisy, _ = librosa.load(self.noisy_files[idx], sr=SR)

        clean = librosa.util.fix_length(clean, size=SAMPLES)
        noisy = librosa.util.fix_length(noisy, size=SAMPLES)

        return torch.FloatTensor(noisy), torch.FloatTensor(clean)


# ===============================
# MODEL
# ===============================

class CochlearModel(nn.Module):

    def __init__(self):
        super().__init__()
        self.encoder = nn.Conv1d(1, 32, 16, stride=2, padding=8)
        self.decoder = nn.ConvTranspose1d(32, 1, 16, stride=2, padding=8)

    def forward(self, x):

        x = x.unsqueeze(1)
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)

        decoded = decoded[:, :, :x.shape[2]]
        return decoded.squeeze(1), encoded


# ===============================
# SI-SNR
# ===============================

def si_snr(est, target):

    if est.dim() == 1:
        est = est.unsqueeze(0)
    if target.dim() == 1:
        target = target.unsqueeze(0)

    est = est - torch.mean(est, dim=1, keepdim=True)
    target = target - torch.mean(target, dim=1, keepdim=True)

    target_energy = torch.sum(target ** 2, dim=1, keepdim=True)

    projection = torch.sum(est * target, dim=1, keepdim=True) * target / (target_energy + 1e-8)
    noise = est - projection

    ratio = torch.sum(projection ** 2, dim=1) / (torch.sum(noise ** 2, dim=1) + 1e-8)

    return 10 * torch.log10(ratio + 1e-8)


def si_snr_loss(est, target):
    return -torch.mean(si_snr(est, target))


# ===============================
# LOAD DATA
# ===============================

dataset = HearingDataset("clean", "noisy")
loader = DataLoader(dataset, batch_size=1, shuffle=True)


# ===============================
# MODEL
# ===============================

model = CochlearModel()
optimizer = optim.Adam(model.parameters(), lr=0.001)


# ===============================
# TRAINING
# ===============================

loss_list = []
si_snr_list = []
stoi_list = []
pesq_list = []

print("Training Started...")

for epoch in range(5):

    total_loss = 0
    total_si = 0
    total_stoi = 0
    total_pesq = 0

    for noisy, clean in loader:

        output, _ = model(noisy)

        loss = si_snr_loss(output, clean)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        total_loss += loss.item()

        out_np = output.detach().numpy()[0]
        clean_np = clean.numpy()[0]

        total_si += si_snr(output.detach(), clean).mean().item()
        total_stoi += stoi(clean_np, out_np, SR)
        total_pesq += pesq(SR, clean_np, out_np, 'wb')

    avg_loss = total_loss / len(loader)
    avg_si = total_si / len(loader)
    avg_stoi = total_stoi / len(loader)
    avg_pesq = total_pesq / len(loader)

    loss_list.append(avg_loss)
    si_snr_list.append(avg_si)
    stoi_list.append(avg_stoi)
    pesq_list.append(avg_pesq)

    print(f"Epoch {epoch} | Loss: {avg_loss:.4f} | SI-SNR: {avg_si:.2f} | STOI: {avg_stoi:.3f} | PESQ: {avg_pesq:.3f}")


# ===============================
# TEST ONE SAMPLE FOR SIGNAL PLOTS
# ===============================

noisy, clean = dataset[0]
output, encoded = model(noisy.unsqueeze(0))

output = output.detach().numpy()[0]
clean = clean.numpy()
noisy = noisy.numpy()


# ===============================
# WAVEFORM PLOTS
# ===============================

t = np.linspace(0, DURATION, SAMPLES)

plt.figure()
plt.plot(t, clean)
plt.title("Clean Signal")
plt.grid(True)
plt.savefig("plots/clean_wave.png")

plt.figure()
plt.plot(t, noisy)
plt.title("Noisy Signal")
plt.grid(True)
plt.savefig("plots/noisy_wave.png")

plt.figure()
plt.plot(t, output)
plt.title("Enhanced Signal")
plt.grid(True)
plt.savefig("plots/enhanced_wave.png")


# ===============================
# SPECTROGRAM PLOTS
# ===============================

def plot_spec(signal, title, filename):
    plt.figure()
    spec = librosa.amplitude_to_db(np.abs(librosa.stft(signal)))
    librosa.display.specshow(spec, sr=SR, x_axis='time', y_axis='hz')
    plt.title(title)
    plt.colorbar()
    plt.savefig(filename)

plot_spec(clean, "Clean Spectrogram", "plots/clean_spec.png")
plot_spec(noisy, "Noisy Spectrogram", "plots/noisy_spec.png")
plot_spec(output, "Enhanced Spectrogram", "plots/enhanced_spec.png")


# ===============================
# METRIC PLOTS
# ===============================

plt.figure()
plt.plot(loss_list)
plt.title("Training Loss")
plt.grid(True)
plt.savefig("plots/loss.png")

plt.figure()
plt.plot(si_snr_list)
plt.title("SI-SNR per Epoch")
plt.grid(True)
plt.savefig("plots/si_snr.png")

plt.figure()
plt.plot(stoi_list)
plt.title("STOI per Epoch")
plt.grid(True)
plt.savefig("plots/stoi.png")

plt.figure()
plt.plot(pesq_list)
plt.title("PESQ per Epoch")
plt.grid(True)
plt.savefig("plots/pesq.png")


# SHOW ALL PLOTS
plt.show()