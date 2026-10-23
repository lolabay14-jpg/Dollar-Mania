import type { ReactNode } from "react";

export function Rows({ columns, rows }: { columns: string[]; rows: ReactNode[][] }) {
  if (rows.length === 0) {
    return <p className="text-sm text-muted">Nothing here yet.</p>;
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="text-xs tracking-wide text-muted uppercase">
            {columns.map((column) => (
              <th key={column} className="px-2 py-2 font-medium">
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index} className="border-t border-line">
              {row.map((cell, cellIndex) => (
                <td key={cellIndex} className="px-2 py-2 align-top">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
