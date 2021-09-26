#!/usr/bin/env bash

# Create output directories
mkdir -p gemini 
mkdir -p gemini/posts

rm gemini/posts/*

# Create list of post file paths
allposts=($HOME/git_proj/johngodlee.github.io/_posts/*.md)

# Only include files which aren't in the future
files=()
for i in "${allposts[@]}"; do
	ts=$(basename "$i" | cut -d'-' -f1-3 | date -f - +%s)
	today=$(date +%s)
	if [ "$ts" -le "$today" ]; then
    	files+=("$i")
	fi
done

for i in ${files[@]}; do
	# Get file name of post
	name=$(basename "$i" | cut -f 1 -d '.')

	# Convert post from markdown to plain text
	md2gemini -p -l paragraph -f $i | sed "s///g" > gemini/posts/$name.gmi

	# Sanitize image and file links 
	sed -i 's/^\[\([^]].*\)\].*/\1/g' gemini/posts/$name.gmi
	sed -i 's/^\!\[\([^]].*\)\](\([^]].*\)).*/=> \2 \1/g' gemini/posts/$name.gmi
	sed -i 's/{{\ssite\.baseurl\s}}/https:\/\/johngodlee.github.io/g' gemini/posts/$name.gmi

	# Sanitize code
	sed -i 's/^```\([^]].*\)/``` \1/g' gemini/posts/$name.gmi

	# Insert title in post
	title=$(awk 'NR==3' $i | sed 's/"//g' | sed 's/title:\s*//g')
	date=$(awk 'NR==4' $i | sed 's/date:\s*//g')
	author="John L. Godlee"
	sed -i "1i# $title\n\nDATE: $date\nAUTHOR: $author\n\n" "gemini/posts/$name.gmi"
done
    
# Create index.gmi and fill
touch gemini/index.gmi

cat gemini_head > gemini/index.gmi

# Create array of posts
all=(gemini/posts/*.gmi)

# Reverse order of posts array
for (( i=${#all[@]}-1; i>=0; i-- )); do 
	rev_all[${#rev_all[@]}]=${all[i]}
done

# Get 10 most recent posts
recent="${rev_all[@]:0:10}"

# Add recent post links to index 
for i in $recent; do
	link=$(echo $i | sed 's/^gemini\///')
	title=$(head -n 1 $i | sed 's/^#\s\+//g')
	date=$(head -n 3 $i | sed -n 3p | sed 's/^DATE:\s\+//g')
	line="${date} - ${title}"
	printf "=> $link $line\n" >> gemini/index.gmi 
done

# Add footer material to index
cat gemini_footer >> gemini/index.gmi 

# Create map file for post archive with header content
touch gemini/posts/index.gmi
cat gemini_posts_head > gemini/posts/index.gmi

# Add posts to posts/index.gmi
rev_all_base=$(basename -a ${rev_all[@]})

for i in $rev_all_base; do
	title=$(head -n 1 gemini/posts/$i | sed 's/^#\s\+//g')
	date=$(head -n 3 gemini/posts/$i | sed -n 3p | sed 's/^DATE:\s\+//g')
	line="${date} - ${title}"
	printf "=> $i $line\n" >> gemini/posts/index.gmi
done

scp gemini/index.gmi johngodlee@r.circumlunar.space:/usr/home/johngodlee/gemini
scp -r gemini/posts johngodlee@r.circumlunar.space:/usr/home/johngodlee/gemini
