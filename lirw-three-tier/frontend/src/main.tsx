import React from "react";
import ReactDOM from "react-dom/client";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import App from "./App.tsx";
import "./index.css";
import ErrorPage from "./ErrorPage.tsx";
import BooksPage from "./BooksPage.tsx";
import AuthorsPage from "./AuthorsPage.tsx";

// Use the same error boundary on child routes so route-level failures do not bypass
// the user-facing error page.
const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    errorElement: <ErrorPage />,
  },
  {
    path: "/books",
    element: <BooksPage />,
    errorElement: <ErrorPage />,
  },
  {
    path: "/authors",
    element: <AuthorsPage />,
    errorElement: <ErrorPage />,
  },
]);

const rootElement = document.getElementById("root");

// Fail explicitly if the Vite root node is missing instead of relying on a non-null assertion.
if (!rootElement) {
  throw new Error("Root element not found.");
}

// Render only after the router and root element are both ready so startup failures are explicit.
ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>,
);
