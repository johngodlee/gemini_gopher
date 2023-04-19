#!/usr/bin/env bash

# Create output directories
mkdir -p gemini 
mkdir -p gemini/posts

# Create list of post file paths
allposts=($HOME/git_proj/johngodlee_website/content/posts/2*.md)

# Only include files which aren't in the future
files=()
today=$(date +%s)
for i in "${allposts[@]}"; do
	ts=$(basename "$i" | cut -d'-' -f1-3 | date -f - +%s)
	if [ "$ts" -le "$today" ]; then
    	files+=("$i")
	fi
done

# Convert blog posts to plain text
for i in ${files[@]}; do
	# Get file name of post, without extension
	name=$(basename "$i" | cut -f 1 -d '.')

	outfile="gemini/posts/$name.gmi"

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
		md2gemini -p -l paragraph -f $i | sed "s///g" > "$outfile"

		# Sanitize image links 
		sed -i 's|{{<\simg\slink="\([^"]*\)".*alt="\([^"]*\)".*|=> https://johngodlee.xyz/\1 \2|g' "$outfile" 

		# Sanitize file links
		sed -i 's|^=>\s/files|=> https://johngodlee.xyz/files|g' "$outfile"

		# Sanitize code
		sed -i 's/^```\([^]].*\)/``` \1/g' "$outfile"

		# Insert title in post
		title=$(awk 'NR==3' $i | sed 's/"//g' | sed 's/title:\s*//g')
		date=$(awk 'NR==4' $i | sed 's/date:\s*//g')
		author="John L. Godlee"
		sed -i "1i# $title\n\nDATE: $date\nAUTHOR: $author\n\n" ""$outfile""
	fi
done
    
# Create index.gmi and fill
touch gemini/index.gmi

cat gemini_head > gemini/index.gmi

# Create array of posts
all=(gemini/posts/*.gmi)
unset 'all[${#all[@]}-1]'

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

# Copy other files
cp bookmarks.gmi gemini/
cp contact.gmi gemini/

# Prepare RSS feed
xmlstarlet ed -d "/rss/channel/item/description" \
	-d "/rss/channel/item/guid" \
	-d "/rss/channel/generator" \
	-d "/rss/channel/atom:link" \
	-d "/rss/channel/description" \
	-d "/@standalone" \
	-u "/rss/channel/link" -v "" \
	-i "/rss/channel/link" -t "attr" -n "rel" -v "self" \
	-i "/rss/channel/link[@rel='self']" -t "attr" -n "type" -v "application/atom+xml" \
	-i "/rss/channel/link[@rel='self']" -t "attr" -n "href" -v "gemini://republic.circumlunar.space/~johngodlee/posts/feed.xml" \
	-a "/rss/channel/link" -t "elem" -n "linktmp" -v "" \
	-i "/rss/channel/linktmp" -t "attr" -n "rel" -v "alternate" \
	-i "/rss/channel/linktmp" -t "attr" -n "type" -v "text/gemini" \
	-i "/rss/channel/linktmp" -t "attr" -n "href" -v "gemini://republic.circumlunar.space/~johngodlee/" \
	-r "/rss/channel/linktmp" -v "link" \
	-a "/rss/channel/title" -t "elem" -n "author" -v "John L. Godlee" \
	-a "/rss/channel/author" -t "elem" -n "id" -v "gemini://republic.circumlunar.space/~johngodlee/" \
	-r "/rss/channel/lastBuildDate" -v "updated" \
	-r "/rss/channel/item/pubDate" -v "updated" \
	-r "/rss/channel/item" -v "entry" \
	-m "/rss/channel/*" "/rss" \
	-d "/rss/channel" \
	-r "/rss" -v "feed" \
	$HOME/git_proj/johngodlee_website/johngodlee.github.io/index.xml |\
	sed 's/xmlns:atom/xmlns/g' |\
	sed 's|http://johngodlee.xyz\(.*\)/</link>|gemini://republic.circumlunar.space/~johngodlee\1.gmi</link>|g' |\
	sed 's|<link>\(.*\)</link>|<link href="\1" />\n    <id>\1</id>|g' >\
	gemini/posts/feed.xml

rsync -avh --stats gemini/posts gemini/index.gmi gemini/bookmarks.gmi gemini/contact.gmi johngodlee@r.circumlunar.space:/usr/home/johngodlee/gemini
