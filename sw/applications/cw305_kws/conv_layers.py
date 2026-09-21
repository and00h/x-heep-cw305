"""Convolutional layer table for the KWS model in model.c.

`id` is the value each node_node_Conv_* function compares `target_layer`
against when arming the TRIG_HIGH glitch trigger. Rows are in execution
order (Conv_69 is the first layer of the network).
"""

# id, name, strides, pads, kernel_shape, dilations, group
CONV_LAYERS = [
    {"id": 69, "name": "node_Conv_69", "strides": (2, 2), "pads": (4, 1, 5, 1), "kernel_shape": (10, 4), "dilations": (1, 1), "group": 1},
    {"id": 61, "name": "node_Conv_61", "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (3, 3), "dilations": (1, 1), "group": 64},
    {"id": 62, "name": "node_Conv_62", "strides": (1, 1), "pads": (0, 0, 0, 0), "kernel_shape": (1, 1), "dilations": (1, 1), "group": 1},
    {"id": 63, "name": "node_Conv_63", "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (3, 3), "dilations": (1, 1), "group": 64},
    {"id": 64, "name": "node_Conv_64", "strides": (1, 1), "pads": (0, 0, 0, 0), "kernel_shape": (1, 1), "dilations": (1, 1), "group": 1},
    {"id": 65, "name": "node_Conv_65", "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (3, 3), "dilations": (1, 1), "group": 64},
    {"id": 66, "name": "node_Conv_66", "strides": (1, 1), "pads": (0, 0, 0, 0), "kernel_shape": (1, 1), "dilations": (1, 1), "group": 1},
    {"id": 67, "name": "node_Conv_67", "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (3, 3), "dilations": (1, 1), "group": 64},
    {"id": 68, "name": "node_Conv_68", "strides": (1, 1), "pads": (0, 0, 0, 0), "kernel_shape": (1, 1), "dilations": (1, 1), "group": 1},
]

CONV_BY_ID = {layer["id"]: layer for layer in CONV_LAYERS}


def _fmt(value):
    return " ".join(str(v) for v in value) if isinstance(value, tuple) else str(value)


def print_table():
    cols = ["id", "name", "strides", "pads", "kernel_shape", "dilations", "group"]
    rows = [[_fmt(layer[c]) for c in cols] for layer in CONV_LAYERS]
    widths = [max(len(c), *(len(r[i]) for r in rows)) for i, c in enumerate(cols)]
    line = "  ".join(c.ljust(w) for c, w in zip(cols, widths))
    print(line)
    print("-" * len(line))
    for r in rows:
        print("  ".join(v.ljust(w) for v, w in zip(r, widths)))


if __name__ == "__main__":
    print_table()
