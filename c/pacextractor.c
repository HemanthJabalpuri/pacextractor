#define _FILE_OFFSET_BITS 64

#include <stddef.h> // size_t, NULL
#include <stdio.h> // fclose, fopen, fprintf, fread, fseek, fseeko, ftell, ftello, fwrite, printf, remove, SEEK_END, SEEK_SET, FILE, stderr
#include <stdlib.h> // exit, free, malloc, EXIT_FAILURE, EXIT_SUCCESS
#include <string.h> // strcmp

#ifdef _WIN32
    #include <direct.h>
    #define MAKE_DIR(dirName) _mkdir(dirName)
#else
    #include <sys/stat.h>
    #define MAKE_DIR(dirName) mkdir(dirName, 0777)
#endif

#include "crc16.h"
#include "pacextractor.h"

_Bool debug = 0;
char namebuf[NAME_LENGTH];
char fiveSpaces[] = "    ";

char* getString(uint16_t* baseString) {
    int length = 0;
    while (baseString > 0 && *baseString != 0 && ++length < NAME_LENGTH) {
        namebuf[length-1] = *baseString & 0xff;
        baseString++;
    }
    namebuf[length] = '\0';
    return namebuf;
}

void printPartHeaderInfo(PartitionHeader* partitionHeader) {
    printf("Size"      "\t\t= %d" "\n", partitionHeader->length);
    printf("FileID"    "\t\t= %s" "\n", getString(partitionHeader->partitionName));
    printf("FileName"    "\t= %s" "\n", getString(partitionHeader->fileName));
    if (partitionHeader->hiPartitionSize == 0x00) {
        printf("FileSize"    "\t= %u" "\n", partitionHeader->loPartitionSize);
    } else {
        printf("HiFileSize"  "\t= %u" "\n", partitionHeader->hiPartitionSize);
        printf("LoFileSize"  "\t= %u" "\n", partitionHeader->loPartitionSize);
        printf("FileSize"   "\t= %lu" "\n", partitionHeader->hiPartitionSize * 0x100000000UL + partitionHeader->loPartitionSize);
    }
    printf("FileFlag"    "\t= %d" "\n", partitionHeader->nFileFlag);
    printf("CheckFlag"   "\t= %d" "\n", partitionHeader->nCheckFlag);
    if (partitionHeader->hiDataOffset == 0x00) {
        printf("DataOffset"  "\t= %u" "\n", partitionHeader->loDataOffset);
    } else {
        printf("HiDataOffset""\t= %u" "\n", partitionHeader->hiDataOffset);
        printf("LoDataOffset""\t= %u" "\n", partitionHeader->loDataOffset);
        printf("DataOffset" "\t= %lu" "\n", partitionHeader->hiDataOffset * 0x100000000UL + partitionHeader->loDataOffset);
    }
    printf("CanOmitFlag" "\t= %d" "\n", partitionHeader->dwCanOmitFlag);
    printf("\n");
}

void checkCRC16(PacHeader* pacHeader, FILE* filestream) {
    size_t rb;
    if (pacHeader->dwMagic != (uint32_t) PAC_MAGIC)
        return;

    printf("Checking CRC Part 1\n");
    fseek(filestream, 0, SEEK_SET);
    unsigned char buffer1[SIZE_OF_PAC_HEADER - 4];
    rb = fread(buffer1, 1, SIZE_OF_PAC_HEADER - 4, filestream);
    if (rb != (SIZE_OF_PAC_HEADER - 4)) {
        fprintf(stderr, "Partition header error\n");
        exit(EXIT_FAILURE);
    }
    uint16_t crc1 = crc16(0, buffer1, SIZE_OF_PAC_HEADER - 4);
    uint16_t crc1InPac = pacHeader->wCRC1;
    if (crc1 != crc1InPac) {
        if (debug) printf("Computed CRC1 = %d, CRC1 in PAC = %d\n", crc1, crc1InPac);
        fprintf(stderr, "CRC Check failed for CRC1\n");
        exit(EXIT_FAILURE);
    }

    printf("Checking CRC Part 2\n");
    uint8_t *buffer = malloc(BUFFSIZE);
    if (buffer == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    fseek(filestream, SIZE_OF_PAC_HEADER, SEEK_SET);
    uint16_t crc2 = 0;
    uint64_t dataSizeLeft = (pacHeader->dwHiSize * 0x100000000UL + pacHeader->dwLoSize) - SIZE_OF_PAC_HEADER;
    uint64_t tsize = dataSizeLeft;
    while (dataSizeLeft > 0) {
        uint32_t copyLength = (dataSizeLeft > BUFFSIZE) ? BUFFSIZE : dataSizeLeft;
        rb = fread(buffer, 1, copyLength, filestream);
        if (rb != copyLength) {
            fprintf(stderr, "\nPartition image extraction error\n");
            exit(EXIT_FAILURE);
        }
        dataSizeLeft -= copyLength;
        crc2 = crc16(crc2, buffer, copyLength);
        printf("\r%llu%%", 100 - ((100 * dataSizeLeft) / tsize));
    }
    printf("\r%s\n", fiveSpaces);
    free(buffer);

    uint16_t crc2InPac = pacHeader->wCRC2;
    if (crc2 != crc2InPac) {
        if (debug) printf("Computed CRC2 = %d, CRC2 in PAC = %d\n\n", crc2, crc2InPac);
        fprintf(stderr, "CRC Check failed for CRC2\n");
        exit(EXIT_FAILURE);
    }
}

void printPacHeaderInfo(PacHeader* pacHeader) {
    printf("Version"    "\t\t= %s"  "\n", getString(pacHeader->szVersion));
    if (pacHeader->dwHiSize == 0x00) {
        printf("Size"       "\t\t= %u"  "\n", pacHeader->dwLoSize);
    } else {
        printf("HiSize"     "\t\t= %u"  "\n", pacHeader->dwHiSize);
        printf("LoSize"     "\t\t= %u"  "\n", pacHeader->dwLoSize);
        printf("Size"      "\t\t= %lu"  "\n", pacHeader->dwHiSize * 0x100000000UL + pacHeader->dwLoSize);
    }
    printf("PrdName"    "\t\t= %s"  "\n", getString(pacHeader->productName));
    printf("FirmwareName" "\t= %s"  "\n", getString(pacHeader->firmwareName));
    printf("FileCount"    "\t= %d"  "\n", pacHeader->partitionCount);
    printf("FileOffset"   "\t= %d"  "\n", pacHeader->partitionsListStart);
    printf("Mode"       "\t\t= %d"  "\n", pacHeader->dwMode);
    printf("FlashType"    "\t= %d"  "\n", pacHeader->dwFlashType);
    printf("NandStrategy" "\t= %d"  "\n", pacHeader->dwNandStrategy);
    printf("IsNvBackup"   "\t= %d"  "\n", pacHeader->dwIsNvBackup);
    printf("NandPageType" "\t= %d"  "\n", pacHeader->dwNandPageType);
    printf("PrdAlias"     "\t= %s"  "\n", getString(pacHeader->szPrdAlias));
    printf("OmaDmPrdFlag" "\t= %d"  "\n", pacHeader->dwOmaDmProductFlag);
    printf("IsOmaDM"    "\t\t= %d"  "\n", pacHeader->dwIsOmaDM);
    printf("IsPreload"    "\t= %d"  "\n", pacHeader->dwIsPreload);
    printf("Magic"     "\t\t= %#x"  "\n", pacHeader->dwMagic);
    printf("CRC1"       "\t\t= %u"  "\n", pacHeader->wCRC1);
    printf("CRC2"       "\t\t= %u"  "\n", pacHeader->wCRC2);
    printf("\n\n");
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: pacextractor [-d] [-c] firmware.pac [outdir]\n");
        fprintf(stderr, "\t -d\t enable debug output\n");
        fprintf(stderr, "\t -c\t compute and verify CRC16\n");
        exit(EXIT_FAILURE);
    }
    char* file = NULL;
    char* outdir = NULL;
    _Bool crc16check = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-d") == 0)
            debug = 1;
        else if (strcmp(argv[i], "-c") == 0)
            crc16check = 1;
        else if (file == NULL)
            file = argv[i];
        else if (outdir == NULL)
            outdir = argv[i];
    }

    FILE* filestream = fopen(file, "rb");
    if (filestream == NULL) {
        fprintf(stderr, "cannot open file %s.\n", file);
        exit(EXIT_FAILURE);
    }

    fseeko(filestream, 0, SEEK_END);
    uint64_t firmwareSize = ftello(filestream);
    if (firmwareSize < sizeof(PacHeader)) {
        fprintf(stderr, "file %s is not a PAC firmware\n", file);
        exit(EXIT_FAILURE);
    }

    PacHeader pacHeader;
    fseek(filestream, 0, SEEK_SET);
    size_t rb = fread(&pacHeader, 1, sizeof(PacHeader), filestream);
    if (rb <= 0) {
        fprintf(stderr, "Error while parsing PAC header\n");
        exit(EXIT_FAILURE);
    }
    if (pacHeader.dwHiSize * 0x100000000UL + pacHeader.dwLoSize != firmwareSize) {
        fprintf(stderr, "Size mismatch error. PAC may be damaged.\n");
        exit(EXIT_FAILURE);
    } else if (strcmp(getString(pacHeader.szVersion), "BP_R1.0.0") != 0 && strcmp(getString(pacHeader.szVersion), "BP_R2.0.1") != 0) {
        fprintf(stderr, "Unsupported PAC version\n");
        exit(EXIT_FAILURE);
    }
    if (debug) printPacHeaderInfo(&pacHeader);

    if (crc16check) checkCRC16(&pacHeader, filestream);

    PartitionHeader** partHeaders = malloc(sizeof(PartitionHeader**) * pacHeader.partitionCount);
    int i;
    fseek(filestream, pacHeader.partitionsListStart, SEEK_SET);
    for (i = 0; i < pacHeader.partitionCount; i++) {
        size_t length = SIZE_OF_PARTITION_HEADER;
        partHeaders[i] = malloc(length);
        rb = fread(partHeaders[i], 1, length, filestream);
        if (rb <= 0) {
            fprintf(stderr, "Partition header error\n");
            exit(EXIT_FAILURE);
        }
        if (partHeaders[i]->length != SIZE_OF_PARTITION_HEADER) {
            fprintf(stderr, "Unknown Partition Header format found\n");
            exit(EXIT_FAILURE);
        }
        if (debug) printPartHeaderInfo(partHeaders[i]);
    }

    printf("\nExtracting...\n\n");

    if (outdir == NULL)
        outdir = "output";

    if (MAKE_DIR(outdir) != 0) {
        fprintf(stderr, "Error creating directory\n");
        exit(EXIT_FAILURE);
    }

    uint8_t *filebuf = malloc(BUFFSIZE);
    if (filebuf == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    for (i = 0; i < pacHeader.partitionCount; i++) {
        if (partHeaders[i]->loPartitionSize == 0 && partHeaders[i]->hiPartitionSize == 0) {
            free(partHeaders[i]);
            continue;
        }
        fseeko(filestream, partHeaders[i]->hiDataOffset * 0x100000000UL + partHeaders[i]->loDataOffset, SEEK_SET);
        char* partFile = getString(partHeaders[i]->fileName);
        char filepath[256];
        snprintf(filepath, sizeof(filepath), "%s/%s", outdir, partFile);
        remove(filepath);
        FILE* newstream = fopen(filepath, "wb");
        printf("%s%s", fiveSpaces, partFile);
        uint64_t dataSizeLeft = partHeaders[i]->hiPartitionSize * 0x100000000UL + partHeaders[i]->loPartitionSize;
        uint64_t tsize = dataSizeLeft;
        while (dataSizeLeft > 0) {
            uint32_t copyLength = (dataSizeLeft > BUFFSIZE) ? BUFFSIZE : dataSizeLeft;
            rb = fread(filebuf, 1, copyLength, filestream);
            if (rb != copyLength) {
                fprintf(stderr, "\nPartition image extraction error\n");
                exit(EXIT_FAILURE);
            }
            dataSizeLeft -= copyLength;
            rb = fwrite(filebuf, 1, copyLength, newstream);
            if (rb != copyLength) {
                fprintf(stderr, "\nPartition image extraction error\n");
                exit(EXIT_FAILURE);
            }
            printf("\r%llu%%", 100 - ((100 * dataSizeLeft) / tsize));
        }
        printf("\r%s%s\n", partFile, fiveSpaces);
        fclose(newstream);
        free(partHeaders[i]);
    }
    printf("\nDone...\n");
    free(partHeaders);
    free(filebuf);
    fclose(filestream);

    return EXIT_SUCCESS;
}
