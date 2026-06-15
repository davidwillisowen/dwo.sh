import os
import re
import shutil

# Paths
posts_dir = "/home/david/dwo.sh/content/posts/"
attachments_dir = "/home/david/obsidian-vault/attachments/"
static_images_dir = "/home/david/dwo.sh/static/images/"

# Step 1: Process each markdown file in the posts directory
for filename in os.listdir(posts_dir):
    if filename.endswith(".md"):
        filepath = os.path.join(posts_dir, filename)
        
        with open(filepath, "r") as file:
            content = file.read()
        
        # Step 2: Find all image links and process them correctly ignoring extra '!'
        images = re.findall(r'!?\[\[([^]]*\.png)\]\]', content)
        
        # Step 3: Replace image links and ensure URLs are correctly formatted using regex substitution
        content = re.sub(
            r'!?\[\[([^]]*\.png)\]\]', 
            lambda m: f"![Image Description](/images/{m.group(1).replace(' ', '%20')})", 
            content
        )
        
        for image in set(images):
            # Step 4: Copy the image to the Hugo static/images directory if it exists
            image_source = os.path.join(attachments_dir, image)
            if os.path.exists(image_source):
                shutil.copy(image_source, static_images_dir)

        # Step 5: Write the updated content back to the markdown file
        with open(filepath, "w") as file:
            file.write(content)

print("Markdown files processed and images copied successfully.")
