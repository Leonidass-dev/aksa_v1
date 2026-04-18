import pickle
import os

filepath = r"C:\Users\Leonidas\Desktop\dataset\WESAD\S2\S2.pkl"
try:
    with open(filepath, 'rb') as f:
        data = pickle.load(f, encoding='latin1')
    print("Keys in pkl:", data.keys())
    print("Label shape:", data['label'].shape if 'label' in data else 'No label array')
    if 'signal' in data:
        print("Signals available in 'wrist':", data['signal']['wrist'].keys() if 'wrist' in data['signal'] else 'No wrist')
        if 'wrist' in data['signal']:
            print("HR shape:", data['signal']['wrist'].get('HR', []).shape)
except Exception as e:
    print(f"Error: {e}")
