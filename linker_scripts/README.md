This file describes the bootloader memory map.

Load addresses
---

| Load Addr | Description                              | Human Readable |
|-----------|------------------------------------------|---------------:|
| 0x7c00    | fixed by bios: first 512 bytes (stage1a) |          31 KB |
| 0x8000    | Start of stage1b                         |          32 KB |
| 0x10000   | 32-bit bootloader code (ArtInium.32)     |          64 KB |
| 0x100000+ | Valid kernel load addresses              |          >1 MB |

stage1a memory map
---

| Addr   | Description       | size  | notes                                       |
|--------|-------------------|-------|---------------------------------------------|
| 0x7c00 | entry, code, data | 510 B | Max size asserted at link time              |
| 0x7dfe | boot magic        | 2   B | 0xAA 55 - BIOS boot magic                   | 
| 0x7e00 | stack bottom      | 0   B | stack grows downwards - see stack top       |
| 0x8000 | stack top         | 512 B | stack is temporarily set to start at 0x8000 |

stage1b memory map
---

| Addr range      | Description       | size          | notes                                     |
|-----------------|-------------------|---------------|-------------------------------------------|
| 0x8000 - 0x9000 | entry, code, data | 0x1000:  4 KB | Max size is asserted at link time         |
| 0x9fff - 0x9000 | stage1b stack     | 0x0fff:  4 KB | stack grows downwards                     |
| 0xa000 - 0xffff | bios data handoff | 0x5fff: 24 KB | framebuffer info, memory map, boot device |

suggested alternative
---
0x8000 - 0xA000  : 8 KB stage 1b
0xA000 - 0xB000  : 4 KB stack
0xB000 - 0x100000: BIOS info structures