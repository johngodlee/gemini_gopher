#!/usr/bin/env bash

# Create output directories
mkdir -p gopher 
mkdir -p gopher/posts

# Create list of post file paths
allposts=($HOME/git_proj/johngodlee_website/content/posts/2*.md)

# Only include files which aren't in the future
files=()
for i in "${allposts[@]}"; do
	ts=$(basename "$i" | cut -d'-' -f1-3 | date -f - +%s)
	today=$(date +%s)
	if [ "$ts" -le "$today" ]; then
    	files+=("$i")
	fi
done

# Convert blog posts to plain text
for i in ${files[@]}; do
	# Get file name of post, without extension
	name=$(basename "$i" | cut -f 1 -d '.')

	outfile="gopher/posts/${name}.txt"

	# Only process newer files
	intime=$(date -r $i +%s)

	if [ -f "$outfile" ]; then
		outtime=$(date -r $outfile +%s)
	else 
		outtime="0"
	fi

	if [ "$outtime" -lt "$intime" ]; then
		echo $name

		# Convert post from markdown to plain text
		pandoc --from markdown-smart --to plain --columns=9999 --reference-links --reference-location=block -o gopher/posts/${name}_wrap.txt $i

		# Sanitize image links 
		sed -i 's|{{<\simg\slink="\([^"]*\)".*alt="\([^"]*\)".*|  ![\2](https://johngodlee.xyz\1)|g' gopher/posts/${name}_wrap.txt
    	
    	# Sanitize file links 
		sed -i 's|:\s/files\(.*\)|(https://johngodlee.xyz/files\1)|g' gopher/posts/${name}_wrap.txt

		# Insert title in post
		title=$(awk 'NR==3' $i | sed 's/"//g' | sed 's/title:\s*//g')
		date=$(awk 'NR==4' $i | sed 's/date:\s*//g')
		title_lo=$(printf '=%.0s' {1..68})
		author="John L. Godlee"
		sed -i "1iTITLE: $title\nDATE: $date\nAUTHOR: $author\n$title_lo\n\n" "gopher/posts/${name}_wrap.txt"

		fold -sw 68 < gopher/posts/${name}_wrap.txt > gopher/posts/${name}.txt
		rm gopher/posts/${name}_wrap.txt

		sed -i "s///g" gopher/posts/${name}.txt

		chmod 644 gopher/posts/${name}.txt
	fi
done

# Create root gophermap and fill with header content 
touch gopher/gophermap
cat gopher_head > gopher/gophermap

# Remove bad line endings

# Create array of all posts
all=(gopher/posts/*.txt)

# Reverse order of posts array
for (( i=${#all[@]}-1; i>=0; i-- )); do 
	rev_all[${#rev_all[@]}]=${all[i]}
done

# Get 10 most recent posts
recent="${rev_all[@]:0:10}"

# Add recent post links to gophermap
for i in $recent; do
	link=$(echo $i | sed 's/^gopher\///')
	title=$(head -n 1 $i | sed 's/^TITLE:\s\+//g')
	date=$(head -n 2 $i | sed -n 2p | sed 's/^DATE:\s\+//g')
	line="${date} - ${title}"
	linecut=$(echo ${line} | cut -c 1-68)
	printf "0$linecut\t$link\n" >> gopher/gophermap
done

# Add footer material to gophermap
cat gopher_footer >> gopher/gophermap

# Create map file for post archive with header content
touch gopher/posts/gophermap 
cat gopher_posts_head > gopher/posts/gophermap 

# Add posts to posts/gophermap
rev_all_base=$(basename -a ${rev_all[@]})

for i in $rev_all_base; do
	title=$(head -n 1 gopher/posts/$i | sed 's/^TITLE:\s\+//g')
	date=$(head -n 2 gopher/posts/$i | sed -n 2p | sed 's/^DATE:\s\+//g')
	line="${date} - ${title}"
	linecut=$(echo ${line} | cut -c 1-68)
	printf "0$linecut\t$i\n" >> gopher/posts/gophermap
done

# Copy other files
cp contact.txt gopher/

# Set file permissions, world read, nonexecutable
find . -name 'gophermap' -print0 | xargs -0 chmod 644
find . -type d -print0 | xargs -0 chmod 755

rsync -avh --stats gopher/contact.txt gopher/gophermap gopher/posts johngodlee@r.circumlunar.space:/usr/home/johngodlee/gopher
