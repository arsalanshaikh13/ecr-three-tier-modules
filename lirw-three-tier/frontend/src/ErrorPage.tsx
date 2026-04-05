import { isRouteErrorResponse, useRouteError } from "react-router-dom";

export default function ErrorPage() {
  const error = useRouteError();

  // Normalize router errors and unexpected runtime errors into one safe message path.
  const title = isRouteErrorResponse(error)
    ? `${error.status} ${error.statusText}`
    : "Oops!";
  // Route responses and thrown runtime errors have different shapes, so format them here once.
  const message = isRouteErrorResponse(error)
    ? error.data || error.statusText
    : error instanceof Error
      ? error.message
      : "Sorry, an unexpected error has occurred.";

  return (
    <div id="error-page" className="min-h-screen p-8 font-mono">
      <h1 className="text-4xl font-bold">{title}</h1>
      <p className="mt-4">Sorry, an unexpected error has occurred.</p>
      <p className="mt-2 text-slate-600">
        <i>{String(message)}</i>
      </p>
    </div>
  );
}
