// Minimal renderer for the specific markdown subset the legal docs use
// (backend/internal/legal/docs/*.md): #/## headers, **bold**, blockquotes,
// "---" rules, and plain paragraphs. Not a general markdown parser.
import type { ReactNode } from "react";

function renderInline(text: string): ReactNode {
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return parts.map((part, i) =>
    part.startsWith("**") && part.endsWith("**") ? <strong key={i}>{part.slice(2, -2)}</strong> : part
  );
}

export function SimpleMarkdown({ content }: { content: string }) {
  const lines = content.split("\n");
  const blocks: ReactNode[] = [];
  let paragraph: string[] = [];

  function flushParagraph(key: string) {
    if (paragraph.length === 0) return;
    blocks.push(
      <p key={key} className="mb-3 text-sm leading-relaxed text-gray-700">
        {renderInline(paragraph.join(" "))}
      </p>
    );
    paragraph = [];
  }

  lines.forEach((line, i) => {
    const trimmed = line.trim();
    if (trimmed === "" || trimmed === "---") {
      flushParagraph(`p${i}`);
      if (trimmed === "---") blocks.push(<hr key={`hr${i}`} className="my-4 border-gray-200" />);
      return;
    }
    if (trimmed.startsWith("## ")) {
      flushParagraph(`p${i}`);
      blocks.push(
        <h2 key={i} className="mb-2 mt-5 text-base font-bold text-gray-900">
          {renderInline(trimmed.slice(3))}
        </h2>
      );
      return;
    }
    if (trimmed.startsWith("# ")) {
      flushParagraph(`p${i}`);
      blocks.push(
        <h1 key={i} className="mb-3 text-lg font-bold text-gray-900">
          {renderInline(trimmed.slice(2))}
        </h1>
      );
      return;
    }
    if (trimmed.startsWith("> ")) {
      flushParagraph(`p${i}`);
      blocks.push(
        <blockquote key={i} className="mb-3 border-l-2 border-emerald-500 pl-3 text-sm italic text-gray-500">
          {renderInline(trimmed.slice(2))}
        </blockquote>
      );
      return;
    }
    paragraph.push(trimmed);
  });
  flushParagraph("p-last");

  return <div>{blocks}</div>;
}
