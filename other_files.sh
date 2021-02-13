#!/usr/bin/env bash

# Convert CV to plain text
pandoc -f markdown -t plain -o cv.txt ~/git_proj/johngodlee.github.io/cv.md

# Link CV to gophermap
cv="John L. Godlee - Curriculum Vitae"
cv_lo=$(echo "$cv" | sed 's/./=/g')

sed -i -e "1i$cv\n$cv_lo\n" cv.txt
sed -i -e '4,5d' cv.txt

# Copy book library to directory
cp ~/git_proj/library/books.txt books.txt

# Copy GPG public key
gpg --armor --export johngodlee@gmail.com > johngodlee.asc

