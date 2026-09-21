import numpy as np

# --- 1. Configuration ---
# Input x: (Channels, Height, Width)
X_SHAPE = (3, 32, 32) 

# Weights w: (Out_Channels, In_Channels, Kernel_Size, Kernel_Size)
# Note: Kernel_Size must be odd for standard 'same' padding
W_OUT_CH = 64
W_K_SIZE = 3
W_SHAPE = (W_OUT_CH, X_SHAPE[0], W_K_SIZE, W_K_SIZE)

def format_float(x):
    """Shortest unique float32 representation for C."""
    return f"{np.format_float_positional(np.float32(x), unique=True, trim='-')}f"

def get_c_array_content(arr):
    """Recursive generator for C array braces to save memory."""
    if arr.ndim == 1:
        return "{" + ", ".join(format_float(x) for x in arr) + "}"
    else:
        return "{\n" + ",\n".join(get_c_array_content(sub) for sub in arr) + "\n}"

# --- 2. Data Generation ---
x_data = np.random.uniform(-1, 1, X_SHAPE).astype(np.float32)
w_data = np.random.uniform(-1, 1, W_SHAPE).astype(np.float32)

# --- 3. Convolution (Same, Stride 1) ---
pad_val = W_K_SIZE // 2
x_padded = np.pad(x_data, ((0, 0), (pad_val, pad_val), (pad_val, pad_val)), mode='constant')

# Output shape: (Out_Channels, Height, Width)
o_shape = (W_OUT_CH, X_SHAPE[1], X_SHAPE[2])
o_clean = np.zeros(o_shape, dtype=np.float32)

print(f"Computing convolution: {X_SHAPE} * {W_SHAPE} -> {o_shape}...")
for oc in range(W_OUT_CH):
    for h in range(X_SHAPE[1]):
        for w in range(X_SHAPE[2]):
            patch = x_padded[:, h:h+W_K_SIZE, w:w+W_K_SIZE]
            o_clean[oc, h, w] = np.sum(patch * w_data[oc])

# --- 4. Pointer Indexing Math ---
def get_indexing_string(name, shape):
    dims = len(shape)
    indices = ["i", "j", "k", "l", "m"][:dims]
    parts = []
    for i in range(dims):
        multiplier = np.prod(shape[i+1:], dtype=int)
        if multiplier > 1:
            parts.append(f"{indices[i]} * {multiplier}")
        else:
            parts.append(f"{indices[i]}")
    return f"{name}[" + "][".join(indices) + f"] -> ptr_{name}[" + " + ".join(parts) + "]"

# --- 5. Write to File ---
filename = "conv_data_arbitrary.h"
with open(filename, "w") as f:
    f.write(f"/* Auto-generated Convolution Data\n")
    f.write(f"   X Shape: {X_SHAPE}\n")
    f.write(f"   W Shape: {W_SHAPE}\n")
    f.write(f"   O Shape: {o_shape}\n*/\n\n")

    for name, data in [("x", x_data), ("w", w_data), ("o_clean", o_clean)]:
        print(f"Writing {name}...")
        dim_str = "".join([f"[{d}]" for d in data.shape])
        f.write(f"// {get_indexing_string(name, data.shape)}\n")
        f.write(f"float __attribute__((section (\"porcodio\"))) {name}{dim_str} = {get_c_array_content(data)};\n\n")

print(f"Done! Created {filename}")