# 05 NCCL Build and Two-Node Validation

## 5.1 Install Dependencies

```bash
sudo apt-get update && sudo apt-get install -y libopenmpi-dev
```

## 5.2 Build NCCL (Blackwell sm_121 support)

Run on both machines (~10–20 min):

```bash
git clone -b v2.30.7-1 https://github.com/NVIDIA/nccl.git ~/nccl
cd ~/nccl
make -j$(nproc) src.build NVCC_GENCODE="-gencode=arch=compute_121,code=sm_121"

git clone https://github.com/NVIDIA/nccl-tests.git ~/nccl-tests
cd ~/nccl-tests
export CUDA_HOME=/usr/local/cuda
export MPI_HOME=/usr/lib/aarch64-linux-gnu/openmpi
export NCCL_HOME=$HOME/nccl/build/
export LD_LIBRARY_PATH=$NCCL_HOME/lib:$CUDA_HOME/lib64/:$MPI_HOME/lib:$LD_LIBRARY_PATH
make -j$(nproc) MPI=1
```

## 5.3 Confirm RoCE Devices and GID

```bash
ibdev2netdev                # physical port → netdev mapping
rdma link show              # expect state ACTIVE / LINK_UP
# GID table: find the RoCE v2 index for your IPv4 (NCCL_IB_GID_INDEX)
for i in 0 1 2 3 4 5; do
  echo "idx$i: $(cat /sys/class/infiniband/<HCA>/ports/1/gids/$i) $(cat /sys/class/infiniband/<HCA>/ports/1/gid_attrs/types/$i)"
done
```

Expected: the IPv4-mapped GID (`::ffff:<fabric-ip>`) is at **idx3** (RoCE v2). After a reboot the
table may rebuild with gaps and the index can drift — the start script in chapter 07 resolves it
automatically by default (`NCCL_IB_GID_AUTO=1`).

## 5.4 Two-Node all_gather Test

Run on head (`<MGMT_IF>` is the shared management interface, `<IP_MGMT_*>` the management IPs):

```bash
export CUDA_HOME=/usr/local/cuda
export MPI_HOME=/usr/lib/aarch64-linux-gnu/openmpi
export NCCL_HOME=$HOME/nccl/build/
export LD_LIBRARY_PATH=$NCCL_HOME/lib:$CUDA_HOME/lib64/:$MPI_HOME/lib:$LD_LIBRARY_PATH

mpirun -np 2 -H <IP_MGMT_A>:1,<IP_MGMT_B>:1 \
  --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -x UCX_NET_DEVICES=<MGMT_IF> \
  -x NCCL_SOCKET_IFNAME=<MGMT_IF> \
  -x OMPI_MCA_btl_tcp_if_include=<MGMT_IF> \
  $HOME/nccl-tests/build/all_gather_perf -b 16G -e 16G -f 2
```

Expected: both ranks see a GB10, `#wrong = 0`, busbw ≈ **21 GB/s** (≈171 Gbit/s, reasonable for a
single cable).

## 5.5 Troubleshooting

| Symptom | Fix |
|---|---|
| mpirun hangs/times out | verify `ssh <IP_MGMT_B> hostname` is passwordless; then a minimal `mpirun -np 2 -H ... hostname` |
| GID/network errors | inspect the GID table per 5.3; reboot both machines to rebuild it |
| `ibv_modify_qp` / `unhandled system error` | RoCEv2 GID index drift: use auto-resolution or fill per 5.3 |

## Official References

- [NCCL for Multiple Sparks playbook](https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/nccl/README.md)
- [NCCL source (tag v2.30.7-1)](https://github.com/NVIDIA/nccl)
- [nccl-tests source](https://github.com/NVIDIA/nccl-tests)
- [NCCL documentation](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/usage/communicators.html)

