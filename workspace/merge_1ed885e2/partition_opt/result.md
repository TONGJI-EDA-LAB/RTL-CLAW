# Yosys Optimization Results
**Date**: 2026-03-20 04:30:56
**Method**: MARO + Yosys
**Total files**: 3
**Optimized**: 3
**Fallback**: 0
**yosys_opt_record**: /home/openclawer/Projects/Partition/workspace/optimization_176e00d2/yosys_opt_record/20260320_043008
**yosys_logs**: /home/openclawer/Projects/Partition/workspace/optimization_176e00d2/partition_opt/_yosys_logs

## File Results

| File | Status | Initial Area | Final Area | Initial Delay | Final Delay | Initial Power | Final Power |
|------|--------|--------------|------------|---------------|-------------|---------------|-------------|
| u_block_1.v | ✅ Optimized | 40.0 | 40.0 | 0.4 | 0.4 | 0.04 | 0.04 |
| u_block_2.v | ✅ Optimized | 118.0 | 118.0 | 0.56 | 0.56 | 0.11800000000000001 | 0.11800000000000001 |
| u_block_3.v | ✅ Optimized | None | None | None | None | None | None |

## Iterations for u_block_1.v

| Iteration | Area | Delay (ns) | Power (mW) |
|-----------|------|------------|------------|
| 1 | 40.0 | 0.4 | 0.04 |

## Iterations for u_block_2.v

| Iteration | Area | Delay (ns) | Power (mW) |
|-----------|------|------------|------------|
| 1 | 118.0 | 0.56 | 0.11800000000000001 |

## Iterations for u_block_3.v

| Iteration | Area | Delay (ns) | Power (mW) |
|-----------|------|------------|------------|
| 1 | None | None | None |

## Equivalence Check Note

⚠️ **Warning**: Yosys ABC equivalence checking may produce false negatives.
This is because Yosys uses internal cell names (e.g., $and, $or) that ABC cannot recognize.
For critical designs, please use iverilog simulation for verification.
