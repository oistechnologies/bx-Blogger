# Welcome to bx-Blogger

This is the sample post that ships with every fresh bx-Blogger install. It's a quick tour of the markdown features the publish pipeline supports, so you can see how your own content will look before you write it.

Feel free to edit or delete this post — once you publish your first real one, a new fresh install would simply skip the seed step.

## Prose, emphasis, and inline code

You can write **bold text**, *italic text*, or ***both at once***. Small phrases like `inline code` render in a monospace font. Regular links like [bx-Blogger on GitHub](https://github.com/) sit inline with the prose, and bare URLs such as https://boxlang.io are auto-linked.

Paragraphs break on blank lines. One line break does not split a paragraph — it stays in flow with the surrounding text. Use blank lines between blocks for proper spacing.

## Headings at every level

The home-feed only renders the post title as an `<h1>`, so inside the body you typically start at `##`. That said, every level works:

### This is an h3

#### This is an h4

##### And an h5 — usually reserved for asides

## Lists

Unordered lists nest naturally:

- Top-level item
- Another top-level item
  - A nested child
  - A second nested child
    - A deeper grandchild
- Back to the top level

Ordered lists carry their numbering even when you mix them with paragraphs:

1. Draft your post in the admin editor
2. Switch to the preview pane to see it rendered
3. Click **Publish** — your post is live

## Blockquotes and call-outs

Standard blockquotes work as you'd expect:

> Writing is thinking. Fluent writing is fluent thinking — which is a finer
> achievement than you might guess.

For emphasis, a lead emoji gives the blockquote a call-out feel:

> 💡 **Tip** — keep your introduction under fifty words. Readers decide whether to keep going inside the first two sentences.

> ⚠️ **Heads up** — the markdown pipeline sanitizes raw HTML. If something you've pasted in doesn't render, check whether it was stripped for safety.

> 📝 **Note** — the preview pane in the editor uses the exact same renderer as the public site, so what you see is what readers get.

## Code

Inline code looks like `this`. For anything more than a word or two, fenced code blocks give you syntax-highlighting classes on the `<code>` element — your theme can style them however you like.

A quick Bash example:

```bash
# Bring the dev stack up
docker compose up -d

# Tail the application logs
docker compose logs -f app
```

A SQL query:

```sql
SELECT id, title, slug, published_at
FROM posts
WHERE status = 'published'
ORDER BY published_at DESC
LIMIT 10;
```

A little JavaScript:

```javascript
const headings = document.querySelectorAll( "h2, h3" );
headings.forEach( ( h, i ) => {
    h.id = h.id || `section-${ i + 1 }`;
} );
```

And some BoxLang for good measure:

```boxlang
class {
    property name="postService" inject="PostService";

    function listRecent( numeric limit = 5 ) {
        return variables.postService.listPublished( limit = arguments.limit );
    }
}
```

## Tables

Markdown tables render with Bootstrap's `.table` class applied automatically:

| Field       | Type          | Required | Notes                                  |
| ----------- | ------------- | -------- | -------------------------------------- |
| title       | VARCHAR(300)  | Yes      | Shown on archive pages and `<title>`   |
| slug        | VARCHAR(200)  | Yes      | Auto-derived if you leave it empty     |
| excerpt     | TEXT          | No       | Used for OG cards and search snippets  |
| published_at| DATETIME      | No       | Null until the first publish           |

Alignment via the header separator row is supported — this table keeps everything left-aligned for scannability.

## Horizontal rules

Three or more hyphens, asterisks, or underscores on their own line produce a horizontal rule, useful for section breaks that don't warrant a heading:

---

## Images and media

Embedded images use the standard markdown syntax. You can reference an uploaded file from your Media library, or an external URL:

```markdown
![Alt text describing the image](/includes/public/media/your-upload.jpg)
```

The media picker in the post editor inserts this snippet for you with the correct alt text and path.

## Next steps

- Open the **Posts** admin, click **New post**, and write something of your own
- Browse the **Themes** panel to see the three bundled themes side-by-side
- Check `DEV-NOTES/PLAN.md` for the roadmap through Phase 11

Happy writing.
