import numpy as np
import sys

CONV_LAYERS = [
    {"id": 0, "name": "net_0", "M": 1, "N": 128, "K": 640},
    {"id": 1, "name": "net_3", "M": 1, "N": 128, "K": 128},
    {"id": 2, "name": "net_6", "M": 1, "N": 128, "K": 128},
    {"id": 3, "name": "net_9", "M": 1, "N": 128, "K": 128},
    {"id": 4, "name": "net_12", "M": 1, "N": 8, "K": 128},
    {"id": 5, "name": "net_15", "M": 1, "N": 128, "K": 8},
    {"id": 6, "name": "net_18", "M": 1, "N": 128, "K": 128},
    {"id": 7, "name": "net_21", "M": 1, "N": 128, "K": 128},
    {"id": 8, "name": "net_24", "M": 1, "N": 128, "K": 128},
    {"id": 9, "name": "net_27", "M": 1, "N": 640, "K": 128},
]


SECOND_STEP = len(sys.argv) > 2 and int(sys.argv[2]) == 1
SUFFIX = sys.argv[3] if len(sys.argv) > 3 else None
LAYER_IDX = int(sys.argv[1])

INPUT_SHAPE  = (CONV_LAYERS[LAYER_IDX]["M"], CONV_LAYERS[LAYER_IDX]["K"])
OUTPUT_SHAPE = (CONV_LAYERS[LAYER_IDX]["M"], CONV_LAYERS[LAYER_IDX]["N"])

# Conv details
LAYER_ID = CONV_LAYERS[LAYER_IDX]["id"]
LAYER_NAME = CONV_LAYERS[LAYER_IDX]["name"]

TARGET_LAYER = f"TARGET_{LAYER_NAME.upper()}"
INPUT_FILE   = f"tensors_in/{LAYER_NAME}_in{(SUFFIX or '_b') if SECOND_STEP else ''}.npy"

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

def get_ptr_math(shape):
    indices = ["i", "j"]
    terms = []
    for i in range(len(shape)):
        stride = int(np.prod(shape[i+1:]))
        if stride > 1:
            terms.append(f"{indices[i]} * {stride}")
        else:
            terms.append(f"{indices[i]}")
    return " + ".join(terms)

x_data = np.load(INPUT_FILE).astype(np.float32)

filename = "input_conv.h"
with open(filename, "w") as f:
    f.write(f"#define IN_FEATURES {CONV_LAYERS[LAYER_IDX]['K']}\n")
    f.write(f"#define OUT_FEATURES {CONV_LAYERS[LAYER_IDX]['N']}\n")

    f.write("/* Auto-generated Convolution Test Data */\n\n")

    f.write(f"// Index: ptr_x[{get_ptr_math(INPUT_SHAPE)}]\n")
    f.write(f"float __attribute__((section (\"important_stuff\"))) x{str(list(INPUT_SHAPE)).replace(', ', '][').replace('[', '[').replace(']', ']')} = \n")
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

print(f"File '{filename}' generated with shapes: X{INPUT_SHAPE}")

with open("fi_conf.h", "w") as f:
    f.write("#ifndef FI_CONF_H\n")
    f.write("#define FI_CONF_H\n");
    f.write(f"#define IN_FEATURES {CONV_LAYERS[LAYER_IDX]['K']}\n")
    f.write(f"#define OUT_FEATURES {CONV_LAYERS[LAYER_IDX]['N']}\n")
    f.write(f"#define {TARGET_LAYER}\n")
    f.write("#endif")