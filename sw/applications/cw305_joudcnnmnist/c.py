import torch
import torch.nn.functional as F

# 1. Setup dimensions
torch.manual_seed(42)
N, C_in, H, W = 2, 3, 10, 10
C_out = 4
kernel_size = 3

# Create Conv2D layer WITH bias
conv = torch.nn.Conv2d(C_in, C_out, kernel_size, bias=True)

# Generate data
X = torch.randn(N, C_in, H, W)
Y = conv(X) 

# ==========================================
# RECONSTRUCTION
# ==========================================

# 2. Extract local blocks and flatten X
X_unf = F.unfold(X, kernel_size=kernel_size)
X_col = X_unf.transpose(1, 2).reshape(-1, C_in * kernel_size * kernel_size)

# 3. Augment X_col with a column of 1s to account for the bias addition
# Shape goes from (N*H*W, C_in*K_H*K_W) -> (N*H*W, C_in*K_H*K_W + 1)
ones_column = torch.ones(X_col.shape[0], 1, dtype=X_col.dtype, device=X_col.device)
X_aug = torch.cat([X_col, ones_column], dim=1)

# 4. Flatten Y
Y_flat = Y.view(N, C_out, -1).transpose(1, 2).reshape(-1, C_out)

# 5. Solve the augmented linear system
# W_aug_T contains both the weights and the biases
W_aug_T = torch.linalg.lstsq(X_aug, Y_flat).solution

# 6. Separate the weights and the bias from the solution
# The weights are everything up to the last row; the bias is the last row
W_flat_T = W_aug_T[:-1, :]
bias_reconstructed = W_aug_T[-1, :]

# 7. Reshape weights back to 4D
W_reconstructed = W_flat_T.T.view(C_out, C_in, kernel_size, kernel_size)

# ==========================================
# VERIFICATION
# ==========================================

weight_error = torch.max(torch.abs(W_reconstructed - conv.weight))
bias_error = torch.max(torch.abs(bias_reconstructed - conv.bias))

print(f"Maximum weight reconstruction error: {weight_error.item():.2e}")
print(f"Maximum bias reconstruction error:   {bias_error.item():.2e}")