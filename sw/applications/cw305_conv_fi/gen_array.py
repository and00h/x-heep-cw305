import numpy as np

IN_CHANNELS = 3
OUT_CHANNELS = 32
SPATIAL_SIZE = 32
KERNEL_SIZE = 3

X_SHAPE = (IN_CHANNELS, SPATIAL_SIZE, SPATIAL_SIZE)
W_SHAPE = (OUT_CHANNELS, IN_CHANNELS, KERNEL_SIZE, KERNEL_SIZE)
O_SHAPE = (OUT_CHANNELS, SPATIAL_SIZE, SPATIAL_SIZE)

def format_float(x):
    return f"{np.format_float_positional(np.float32(x), unique=True, trim='-')}f"

def get_c_array_content(data, is_zero=False):
    if is_zero:
        if data.ndim == 1:
            return "{" + ", ".join(["0.0f"] * data.shape[0]) + "}"
        return "{\n" + ",\n".join(get_c_array_content(sub, True) for sub in data) + "\n}"
    
    if data.ndim == 1:
        return "{" + ", ".join(format_float(x) for x in data) + "}"
    return "{\n" + ",\n".join(get_c_array_content(sub) for sub in data) + "\n}"

x_data = np.random.uniform(-1, 1, X_SHAPE).astype(np.float32)
w_data = np.random.uniform(-1, 1, W_SHAPE).astype(np.float32)

pad = KERNEL_SIZE // 2
x_padded = np.pad(x_data, ((0, 0), (pad, pad), (pad, pad)), mode='constant')
o_clean = np.zeros(O_SHAPE, dtype=np.float32)

for oc in range(OUT_CHANNELS):
    for h in range(SPATIAL_SIZE):
        for w in range(SPATIAL_SIZE):
            patch = x_padded[:, h:h+KERNEL_SIZE, w:w+KERNEL_SIZE]
            o_clean[oc, h, w] = np.sum(patch * w_data[oc])

def get_ptr_math(shape):
    indices = ["i", "j", "k", "l"]
    terms = []
    for i in range(len(shape)):
        stride = int(np.prod(shape[i+1:]))
        if stride > 1:
            terms.append(f"{indices[i]} * {stride}")
        else:
            terms.append(f"{indices[i]}")
    return " + ".join(terms)

filename = "conv_data.h"
with open(filename, "w") as f:
    f.write("/* Auto-generated Convolution Test Data */\n\n")

    f.write(f"// Index: ptr_x[{get_ptr_math(X_SHAPE)}]\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) x{str(list(X_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    f.write(get_c_array_content(x_data) + ";\n\n")
    np.save("x.npy", x_data)

    f.write(f"// Index: ptr_w[{get_ptr_math(W_SHAPE)}]\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) w{str(list(W_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    f.write(get_c_array_content(w_data) + ";\n\n")
    np.save("w.npy", w_data)

    f.write(f"// Index: ptr_o[{get_ptr_math(O_SHAPE)}]\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) o{str(list(O_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    f.write(get_c_array_content(o_clean, is_zero=True) + ";\n\n")

    f.write(f"// Reference Result for validation\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) o_clean{str(list(O_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    f.write(get_c_array_content(o_clean) + ";\n")
    np.save("o_clean.npy", o_clean)

print(f"File '{filename}' generated with shapes: X{X_SHAPE}, W{W_SHAPE}, O{O_SHAPE}")