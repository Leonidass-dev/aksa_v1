import torch
import torch.nn as nn

class LSTMAutoencoder(nn.Module):
    def __init__(self, input_size, hidden_size=16, num_layers=1):
        """
        Tez Modül 7: Anomali Tespiti için LSTM Autoencoder.
        Zaman serisi penceresini sıkıştırıp (encode) yeniden üretmeye (decode) çalışır.
        """
        super(LSTMAutoencoder, self).__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        
        # Encoder
        self.encoder = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True)
        # Decoder
        self.decoder = nn.LSTM(hidden_size, input_size, num_layers, batch_first=True)
        
    def forward(self, x):
        # x shape: (batch_size, seq_len, input_size)
        
        # Encode
        _, (hidden, _) = self.encoder(x)
        # hidden shape (num_layers, batch, hidden_size)
        
        # Decode aşamasında seq_len kadar repeat yapmak gerekir (örn. 1 zaman adımı ise 1 kere)
        # Sequence uzunluğumuz şu an 1 olduğu için repeat(1, seq_len, 1) yeterlidir.
        seq_len = x.size(1)
        hidden = hidden[-1] # Son katmanın hidden state'i: (batch, hidden_size)
        hidden = hidden.unsqueeze(1).repeat(1, seq_len, 1) # (batch, seq_len, hidden_size)
        
        # Decode
        out, _ = self.decoder(hidden)
        # out shape: (batch_size, seq_len, input_size)
        
        return out
