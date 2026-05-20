import torch
import torch.nn as nn


class ExerciseRNN(nn.Module):
    def __init__(self, input_size, hidden_size=32, num_classes=5):
        """
        Tez Modül 6: Egzersiz Tavsiye RNN Modeli
        Son 14 günün aktivite, uyku ve risk durumu üzerinden hangi egzersiz tipinin
        kullanıcı tarafından daha çok benimseneceği / tamamlanacağı olasılığını üretir.
        """
        super(ExerciseRNN, self).__init__()
        self.rnn = nn.RNN(input_size, hidden_size, batch_first=True)
        self.fc = nn.Linear(hidden_size, num_classes)

    def forward(self, x):
        # x shape (batch, 14, input_size)
        out, _ = self.rnn(x)
        # out shape: (batch, 14, hidden_size)
        out = out[:, -1, :]  # Son günün gizli durumunu al
        out = self.fc(out)
        return torch.sigmoid(out)  # 5 Egzersiz tipi için tamamlama olasılığı (0-1)
