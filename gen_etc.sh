#!/bin/sh
# Create compressed and decompressed ETC textures.
# Interfaces with etcpack v4.0.1.

# Usage:
#     gen_etc.sh <etcpack_binary> <input_image>

# Exit on command error or usage of unset parameter
set -eu

# Input Parameters
codec=$1
inFilePath=$2

# Settings
OutCompressedDir=etcCompressed
OutDecompressedDir=etcDecompressed
verbose=1
FmtList=("R" "R_signed" "RG" "RG_signed" "RGB" "RGBA1" "RGBA8")
TexSizes=("3x3" "4x4" "101x100")

# Test Setup
inFile=${inFilePath##.*/}
output="/dev/"
if (( $verbose ));then
   output+="stdout"
else
   output+="null"
fi

# Creates .PKMs in the specified directory
function create_compressed_mipmaps() 
{
   local uncompressedImg=$1
   local compressedDir=$2
   local format=$3
   $codec $uncompressedImg $compressedDir -f $format -mipmaps > $output
}

# Main Routine

# Don't generate over previously generated directories
mkdir $OutCompressedDir $OutDecompressedDir

for dim in "${TexSizes[@]}"; do

   # Resize the input image to <, =, >, 4x4 texels
   sizeImage="r$dim-$inFile"
   convert $inFilePath -resize $dim\! $sizeImage

   # Create compressed and decompressed textures for each image
   for fmt in "${FmtList[@]}"; do

      # Create directory to store outputs
      compressedDir=$OutCompressedDir/$fmt
      decompressedDir=$OutDecompressedDir/$fmt
      mkdir -p $compressedDir $decompressedDir 

      # Generate compressed miplevels for input image
      # NOTE: It's assumed the codec will set an opaque alpha (100%)
      # for a $fmt with an alpha channel.
      create_compressed_mipmaps $sizeImage $compressedDir $fmt

      # Create compressed textures with varying alpha values
      if [[ $fmt =~ "RGBA" ]]; then

         # Create transparent compressed texture
         transparencyFile=transparent-$sizeImage
         convert $sizeImage -alpha transparent $transparencyFile
         create_compressed_mipmaps $transparencyFile $compressedDir $fmt
         rm $transparencyFile

         # Create 50% alpha compressed texture
         if [[ $fmt == "RGBA8" ]]; then
            transparencyFile=mid-$sizeImage
            convert $sizeImage -evaluate Divide 2 +channel $transparencyFile
            create_compressed_mipmaps $transparencyFile $compressedDir $fmt
            rm $transparencyFile
         fi

      fi

      # Decompress each compressed miplevel
      for file in $( ls $compressedDir ); do
         inFileCompressed=$compressedDir/$file
         $codec $inFileCompressed $decompressedDir -ext PNG > $output
      done

   done

   # Cleanup intermediate file
   rm $sizeImage

done
