import numpy as np
import sys

CONV_LAYERS = [
    {"id": 0, "name": "conv1", "in_shape": (1,1,28,28), "out_shape": (1,16,28,28), "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (16, 1, 3, 3), "dilations": (1, 1), "group": 1},
    {"id": 1, "name": "conv2", "in_shape": (1,16,14,14), "out_shape": (1,32,14,14), "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (32, 16, 3, 3), "dilations": (1, 1), "group": 1},
    {"id": 2, "name": "fc1", "M": 1, "N": 16, "K": 1568},
    {"id": 3, "name": "fc2", "M": 1, "N": 10, "K": 16},
]


SECOND_STEP = len(sys.argv) > 2 and int(sys.argv[2]) == 1
SUFFIX = sys.argv[3] if len(sys.argv) > 3 else None
LAYER_IDX = int(sys.argv[1])

is_conv_layer = "conv" in CONV_LAYERS[LAYER_IDX]["name"]

if is_conv_layer:
    INPUT_SHAPE  = CONV_LAYERS[LAYER_IDX]["in_shape"]
    OUTPUT_SHAPE = CONV_LAYERS[LAYER_IDX]["out_shape"]

    # Conv details
    LAYER_ID = CONV_LAYERS[LAYER_IDX]["id"]
    LAYER_NAME = CONV_LAYERS[LAYER_IDX]["name"]
    WEIGHT_SHAPE = CONV_LAYERS[LAYER_IDX]["kernel_shape"]
    PADDING = CONV_LAYERS[LAYER_IDX]["pads"]
    PADDING_TOP, PADDING_LEFT, PADDING_BOTTOM, PADDING_RIGHT = PADDING
    STRIDE = CONV_LAYERS[LAYER_IDX]["strides"][0]
    GROUPS = CONV_LAYERS[LAYER_IDX]["group"]
    OUT_GROUP_SIZE = WEIGHT_SHAPE[0] // GROUPS
    IN_GROUP_SIZE = INPUT_SHAPE[1] // GROUPS

    IN_CHANNELS = INPUT_SHAPE[1]
    OUT_CHANNELS = OUTPUT_SHAPE[1]
    SPATIAL_SIZE_W = INPUT_SHAPE[3]
    SPATIAL_SIZE_H = INPUT_SHAPE[2]
    KERNEL_SIZE_W = WEIGHT_SHAPE[3]
    KERNEL_SIZE_H = WEIGHT_SHAPE[2]

    X_SHAPE = (1, IN_CHANNELS, SPATIAL_SIZE_H, SPATIAL_SIZE_W)
    W_SHAPE = (OUT_CHANNELS, IN_CHANNELS // GROUPS, KERNEL_SIZE_H, KERNEL_SIZE_W)
    H_out = (SPATIAL_SIZE_H + PADDING_TOP + PADDING_BOTTOM - (KERNEL_SIZE_H - 1) - 1) // STRIDE + 1
    W_out = (SPATIAL_SIZE_W + PADDING_LEFT + PADDING_RIGHT - (KERNEL_SIZE_W - 1) - 1) // STRIDE + 1
    O_SHAPE = (OUT_CHANNELS, H_out, W_out)
else:
    INPUT_SHAPE  = (CONV_LAYERS[LAYER_IDX]["M"], CONV_LAYERS[LAYER_IDX]["K"])
    OUTPUT_SHAPE = (CONV_LAYERS[LAYER_IDX]["M"], CONV_LAYERS[LAYER_IDX]["N"])

    # Conv details
    LAYER_ID = CONV_LAYERS[LAYER_IDX]["id"]
    LAYER_NAME = CONV_LAYERS[LAYER_IDX]["name"]

TARGET_LAYER = f"TARGET_{LAYER_NAME.upper()}"
INPUT_FILE   = INPUT_FILE   = f"tensors_in/{LAYER_NAME}_in{(SUFFIX or '_b') if SECOND_STEP else ''}.npy"

def format_float(x):
    return "0.0f" if x == 0. else f"{np.format_float_positional(np.float32(x), unique=True, trim='-')}f"

def get_c_array_content(data, is_zero=False):
    if is_zero:
        if data.ndim == 1:
            return "{" + ", ".join(["0.0f"] * data.shape[0]) + "}"
        return "{\n" + ",\n".join(get_c_array_content(sub, True) for sub in data) + "\n}"
    
    if data.ndim == 1:
        return "{" + ", ".join(format_float(x) for x in data) + "}"
    return "{\n" + ",\n".join(get_c_array_content(sub) for sub in data) + "\n}"

x_data = np.load(INPUT_FILE).astype(np.float32)

#x_padded = np.pad(x_data, ((0,0), (0, 0), (PADDING_TOP, PADDING_BOTTOM), (PADDING_LEFT, PADDING_RIGHT)), mode='constant')
#o_clean = np.zeros(O_SHAPE, dtype=np.float32)

# for oc in range(OUT_CHANNELS):
#     for h in range(SPATIAL_SIZE):
#         for w in range(SPATIAL_SIZE):
#             patch = x_padded[:, h:h+KERNEL_SIZE, w:w+KERNEL_SIZE]
#             o_clean[oc, h, w] = np.sum(patch * w_data[oc])

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

filename = "input_conv.h"
with open(filename, "w") as f:
    if is_conv_layer:
        f.write(f"#define IN_CHANNELS {IN_CHANNELS}\n")
        f.write(f"#define OUT_CHANNELS {OUT_CHANNELS}\n")
        f.write(f"#define SPATIAL_SIZE_W {SPATIAL_SIZE_W}\n")
        f.write(f"#define SPATIAL_SIZE_H {SPATIAL_SIZE_H}\n")
        f.write(f"#define OUT_SPATIAL_SIZE_H {OUTPUT_SHAPE[2]}\n")
        f.write(f"#define OUT_SPATIAL_SIZE_W {OUTPUT_SHAPE[3]}\n")
        f.write(f"#define TARGET_CONV\n")
    else:
        f.write(f"#define IN_FEATURES {CONV_LAYERS[LAYER_IDX]['K']}\n")
        f.write(f"#define OUT_FEATURES {CONV_LAYERS[LAYER_IDX]['N']}\n")

    f.write("/* Auto-generated Convolution Test Data */\n\n")

    f.write(f"// Index: ptr_x[{get_ptr_math(X_SHAPE if is_conv_layer else INPUT_SHAPE)}]\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) x{str(list(X_SHAPE if is_conv_layer else INPUT_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    f.write(get_c_array_content(x_data) + ";\n\n")
    np.save("x.npy", x_data)

    # f.write(f"// Index: ptr_w[{get_ptr_math(W_SHAPE)}]\n")
    # f.write(f"float __attribute__((section (\"important_stuff\"))) w{str(list(W_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    # f.write(get_c_array_content(w_data) + ";\n\n")
    # np.save("w.npy", w_data)

    # f.write(f"// Index: ptr_o[{get_ptr_math(O_SHAPE)}]\n")
    # f.write(f"float __attribute__((section (\"important_stuff\"))) o{str(list(O_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    # f.write(get_c_array_content(o_clean, is_zero=True) + ";\n\n")

    # f.write(f"// Reference Result for validation\n")
    # f.write(f"float __attribute__((section (\"important_stuff\"))) o_clean{str(list(O_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
    # f.write(get_c_array_content(o_clean) + ";\n")
    # np.save("o_clean.npy", o_clean)

print(f"File '{filename}' generated with shapes: X{X_SHAPE if is_conv_layer else INPUT_SHAPE}")

with open("fi_conf.h", "w") as f:
    f.write("#ifndef FI_CONF_H\n")
    f.write("#define FI_CONF_H\n");
    if is_conv_layer:
        f.write(f"#define IN_CHANNELS {IN_CHANNELS}\n")
        f.write(f"#define OUT_CHANNELS {OUT_CHANNELS}\n")
        f.write(f"#define SPATIAL_SIZE_W {SPATIAL_SIZE_W}\n")
        f.write(f"#define SPATIAL_SIZE_H {SPATIAL_SIZE_H}\n")
        f.write(f"#define OUT_SPATIAL_SIZE_H {OUTPUT_SHAPE[2]}\n")
        f.write(f"#define OUT_SPATIAL_SIZE_W {OUTPUT_SHAPE[3]}\n")
        f.write(f"#define {TARGET_LAYER}\n")
        f.write(f"#define TARGET_CONV\n")
    else:
        f.write(f"#define IN_FEATURES {CONV_LAYERS[LAYER_IDX]['K']}\n")
        f.write(f"#define OUT_FEATURES {CONV_LAYERS[LAYER_IDX]['N']}\n")
        f.write(f"#define {TARGET_LAYER}\n")
    f.write("#endif")
    