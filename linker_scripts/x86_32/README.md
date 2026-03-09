This file describes the bootloader memory map.

Load addresses
---

| Load Addr | Description                              | Human Readable |
|-----------|------------------------------------------|---------------:|
| 0x7c00    | fixed by bios: first 512 bytes (stage1a) |          31 KB |
| 0x8000    | Start of stage1b                         |          32 KB |
| 0x10000   | 32-bit bootloader code (ArtInitium.32)     |          64 KB |
| 0x100000+ | Valid kernel load addresses              |          >1 MB |

stage1a memory map
---

| Addr range      | Description                        | size  | notes                            |
|-----------------|------------------------------------|-------|----------------------------------|
| 0x7C00 - 0x7DFE | entry, code, data                  | 510 B | Max size asserted at link time   |
| 0x7DFE - 0x7E00 | boot magic                         | 2 B   | 0xAA55 - BIOS boot magic         | 
| 0x7E00          | stage1a stack pointer (grows down) | -     | Initial SP value                 |
| 0x7E00 - 0x8000 | Free memory (used by stack)        | 512 B | Stack grows downward from 0x7E00 |

stage1b memory map
---

| Addr range      | Description                          | size           | notes                                                                          |
|-----------------|--------------------------------------|----------------|--------------------------------------------------------------------------------|
| 0x8000 - 0xFC00 | stage1b code + data                  | 0x1000:  31 KB | Code, strings, boot info, VBE data, memory map. Max size asserted at link time |
| 0xFFFF          | stage1b stack pointer (grows down)   | at least 1 KB  | Stack grows downwards                                                          |
| 0x10000+        | Stage 2 (32-bit protected mode code) | ...            | Loaded after stage1b completes                                                 |

stage2 memory map
---

| Addr range        | Description        | size  | notes                                       |
|-------------------|--------------------|-------|---------------------------------------------|
| 0x10000 - 0x9fc00 | stage2 code + data | 64 KB | Code, data, boot info, VBE handling         |
| 0x100000          | Kernel load area   | >1 MB | Kernel loaded here after stage2 initializes |     