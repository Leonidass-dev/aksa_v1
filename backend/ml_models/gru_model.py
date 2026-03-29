import torch
import torch.nn as nn

class RiskGRU(nn.Module):
    def __init__(self, input_size, hidden_size=32, num_layers=1, num_classes=3):
        """
        Tez Modül 3: Zaman bağımlı durumları yakalayan GRU Modeli.
        """
        super(RiskGRU, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        
        # GRU Katmanı
        self.gru = nn.GRU(input_size, hidden_size, num_layers, batch_first=True)
        
        # Tam Bağlı Sınıflandırma Katmanları
        self.fc1 = nn.Linear(hidden_size, 16)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(16, num_classes)
        
    def forward(self, x):
        # x shape: (batch_size, seq_len, input_size)
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(x.device)
        
        out, _ = self.gru(x, h0)
        
        # Dizinin son zaman adımının çıktısını (hidden state) al
        out = out[:, -1, :]
        
        out = self.fc1(out)
        out = self.relu(out)
        out = self.fc2(out)
        return out
