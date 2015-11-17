#!/bin/sh
# Create compressed and decompressed ETC textures

# Usage: ./gen_etc.sh /path/to/etcpack <input_image>

set -eu

codec=$1
inFilePath=$2
inFile=${inFilePath##.*/}
silence=0

output="/dev/"
if (( $silence ));then
   output+="null"
else
   output+="stdout"
fi

FmtList=("R" "R_signed" "RG" "RG_signed" "RGB" "RGBA1" "RGBA8")
TexSizes=("3x3" "4x4" "101x100")

# Creates .PKMs in the specified directory
function create_compressed_mipmaps() 
{
   uncompressedImg=$1
   compressedDir=$2
   format=$3
   $codec $uncompressedImg $compressedDir -f $format -mipmaps > $output
}

# Resize the input image to < = > 4x4 texels
for dim in "${TexSizes[@]}"; do
   sizeImage="r$dim-$inFile"
   convert $inFilePath -resize $dim\! $sizeImage


   # Create compressed and decompressed textures for each image
   for fmt in "${FmtList[@]}"; do

      # Create directory to store outputs
      compressedDir=etcCompressed/$fmt
      decompressedDir=etcDecompressed/$fmt
      mkdir -p $compressedDir $decompressedDir 

      # Generate compressed miplevels for input image
      create_compressed_mipmaps $sizeImage $compressedDir $fmt

      # Create compressed textures with varying alpha values
      if [[ $fmt =~ "RGBA" ]]; then

         # Create transparent compressed texture
         transparencyFile=transparent-$sizeImage
         convert $sizeImage -alpha transparent $transparencyFile
         create_compressed_mipmaps $transparencyFile $compressedDir $fmt

         # Create 50% alpha compressed texture
         if [[ $fmt == "RGBA8" ]]; then
            transparencyFile=mid-$sizeImage
            convert $sizeImage -evaluate Divide 2 +channel $transparencyFile
            create_compressed_mipmaps $transparencyFile $compressedDir $fmt
         fi

      fi


      # Decompress each compressed miplevel
      for file in $( ls $compressedDir ); do
         inFileCompressed=$compressedDir/$file
         $codec $inFileCompressed $decompressedDir -ext PNG > $output
      done

   done
done
