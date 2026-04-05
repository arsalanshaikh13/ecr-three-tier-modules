import { Alert, Button, Table } from "antd";
import "./App.css";
import { useEffect, useState } from "react";
import { IconEdit } from "./components/IconEdit";
import { IconDelete } from "./components/IconDelete";
import { IconView } from "./components/IconView";
import { Link } from "react-router-dom";
import { AddEditBookModal } from "./components/AddEditBookModal";
import { ViewBookModal } from "./components/ViewBookModal";
import { DeleteBookModal } from "./components/DeleteBookModal";
import { Book, BookDTO, BookFormDTO } from "./models/Books";
import { Author } from "./models/Author";

// VITE_API_URL is expected to point to the API base path (for example "/api").
// Trim a trailing slash once so endpoint construction stays predictable.
const API_URL = (import.meta.env.VITE_API_URL || "").replace(/\/$/, "");

const columns = [
  {
    title: "ID",
    dataIndex: "id",
    key: "id",
  },
  {
    title: "Title",
    dataIndex: "title",
    key: "title",
  },
  {
    title: "Description",
    dataIndex: "description",
    key: "description",
  },
  {
    title: "Release Date",
    dataIndex: "releaseDate",
    key: "releaseDate",
  },
  {
    title: "Author",
    dataIndex: "author",
    key: "author",
  },
  {
    title: "Created Date",
    dataIndex: "createdAt",
    key: "createdAt",
  },
  {
    title: "Updated Date",
    dataIndex: "updatedAt",
    key: "updatedAt",
  },
  {
    title: "Actions",
    dataIndex: "actions",
    key: "actions",
  },
];

type BooksResponse = {
  books: Book[];
  message?: string;
};

type AuthorsResponse = {
  authors: Author[];
  message?: string;
};

function BooksPage() {
  const [books, setBooks] = useState<Book[]>([]);
  const [authors, setAuthors] = useState<Author[]>([]);
  const [dataSource, setDataSource] = useState<BookDTO[]>([]);
  const [activeBook, setActiveBook] = useState<Book>();
  const [isAddEditModalOpen, setIsAddEditModalOpen] = useState(false);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isSuccessAlertVisible, setIsSuccessAlertVisible] = useState(false);
  const [isErrorAlertVisible, setIsErrorAlertVisible] = useState(false);
  const [message, setMessage] = useState("");
  const [isEdit, setIsEdit] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Load books and authors together on first render so the page has consistent form dependencies.
    loadInitialData();
  }, []);

  useEffect(() => {
    // Rebuild the table rows whenever the canonical books list changes.
    formatBooksForDisplay(books);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [books]);

  const showAlert = (nextMessage: string, type: "success" | "error") => {
    // Keep one helper for success/error banners so CRUD handlers stay consistent.
    setMessage(nextMessage);
    setIsSuccessAlertVisible(type === "success");
    setIsErrorAlertVisible(type === "error");

    setTimeout(() => {
      setIsSuccessAlertVisible(false);
      setIsErrorAlertVisible(false);
    }, 5000);
  };

  const extractErrorMessage = (error: unknown) => {
    // Normalize runtime values into a safe message for UI alerts.
    if (error instanceof Error) {
      return error.message;
    }

    return "Something unexpected has happened. Please try again later.";
  };

  const requestJson = async <T,>(
    input: RequestInfo | URL,
    init?: RequestInit,
  ): Promise<T> => {
    // Parse non-2xx responses as text first because proxy or backend failures may not be JSON.
    const response = await fetch(input, init);

    if (!response.ok) {
      const message = await response.text();
      throw new Error(
        message || `Request failed with status ${response.status}`,
      );
    }

    return response.json() as Promise<T>;
  };

  const loadInitialData = async () => {
    try {
      if (!API_URL) {
        throw new Error("VITE_API_URL is not configured.");
      }

      // Table loading state makes backend failures visible instead of leaving the page looking idle.
      setLoading(true);

      // Load books and authors together so the page does not partially render with stale dependencies.
      const [booksResponse, authorsResponse] = await Promise.all([
        requestJson<BooksResponse>(`${API_URL}/books`),
        requestJson<AuthorsResponse>(`${API_URL}/authors`),
      ]);

      setBooks(booksResponse.books);
      setAuthors(authorsResponse.authors);
    } catch (error) {
      console.error(error);
      setBooks([]);
      setAuthors([]);
      showAlert(extractErrorMessage(error), "error");
    } finally {
      setLoading(false);
    }
  };

  const editBook = async (book: BookFormDTO) => {
    try {
      if (activeBook) {
        const response = await requestJson<BooksResponse>(
          `${API_URL}/books/${activeBook.id}`,
          {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(book),
          },
        );

        setBooks(response.books);
        showAlert(response.message || "Book updated successfully!", "success");
      }
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const addBook = async (book: BookFormDTO) => {
    try {
      const response = await requestJson<BooksResponse>(`${API_URL}/books`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(book),
      });

      setBooks(response.books);
      showAlert(response.message || "Book created successfully!", "success");
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const bookAddEdit = (book: BookFormDTO) => {
    // Reuse one submit path for create/edit so modal wiring stays simple.
    if (isEdit) {
      editBook(book);
      return;
    }

    addBook(book);
  };

  const bookDelete = async () => {
    try {
      if (activeBook) {
        const response = await requestJson<BooksResponse>(
          `${API_URL}/books/${activeBook.id}`,
          {
            method: "DELETE",
            headers: {
              "Content-Type": "application/json",
            },
          },
        );

        setBooks(response.books);
        showAlert(response.message || "Book deleted successfully!", "success");
      }
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const handleBookAdd = () => {
    // Reset the active record before opening the modal in create mode.
    setActiveBook(undefined);
    setIsEdit(false);
    setIsAddEditModalOpen(true);
  };

  const handleBookEdit = (book: Book) => {
    setActiveBook(book);
    setIsEdit(true);
    setIsAddEditModalOpen(true);
  };

  const handleBookView = (book: Book) => {
    setActiveBook(book);
    setIsViewModalOpen(true);
  };

  const handleBookDelete = (book: Book) => {
    setActiveBook(book);
    setIsDeleteModalOpen(true);
  };

  const formatBooksForDisplay = (nextBooks: Book[]) => {
    // Clear stale rows when the API returns an empty list or a request fails.
    if (nextBooks.length === 0) {
      setDataSource([]);
      return;
    }

    const nextDataSource: BookDTO[] = [];

    for (const book of nextBooks) {
      const bookObj = {
        key: book.id,
        id: book.id,
        title: book.title,
        releaseDate: book.releaseDate,
        description: book.description,
        pages: book.pages,
        author: book?.name,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
        actions: (
          <div className="flex space-x-4">
            <Button icon={<IconEdit />} onClick={() => handleBookEdit(book)} />
            <Button
              type="primary"
              icon={<IconView />}
              onClick={() => handleBookView(book)}
            />
            <Button
              type="primary"
              icon={<IconDelete />}
              danger
              onClick={() => handleBookDelete(book)}
            />
          </div>
        ),
      };

      nextDataSource.push(bookObj);
    }

    setDataSource(nextDataSource);
  };

  return (
    <div className="h-screen font-mono p-4">
      <header className="relative py-2 border-b">
        <Button size="large" className="rounded-none absolute">
          <Link to={`/`}>Dashboard</Link>
        </Button>
        <h1 className="text-center font-bold text-5xl">MANAGE BOOKS</h1>
      </header>
      <main className="py-4 px-4 space-y-6">
        <div className="flex justify-between">
          <Button
            type="primary"
            size="large"
            className="rounded-none"
            onClick={handleBookAdd}
          >
            <span className="font-bold">+</span>&nbsp; Add Book
          </Button>
          {isSuccessAlertVisible && (
            <Alert message={message} type="success" showIcon closable />
          )}
          {isErrorAlertVisible && (
            <Alert message={message} type="error" showIcon closable />
          )}
        </div>
        <div>
          <Table
            dataSource={dataSource}
            columns={columns}
            size="middle"
            loading={loading}
          />
        </div>
      </main>
      <AddEditBookModal
        authors={authors}
        initialValues={
          activeBook && { ...activeBook, author: activeBook?.authorId }
        }
        isEdit={isEdit}
        isModalOpen={isAddEditModalOpen}
        setIsModalOpen={setIsAddEditModalOpen}
        onOk={bookAddEdit}
      />
      <ViewBookModal
        book={activeBook && { ...activeBook, author: activeBook?.name }}
        isModalOpen={isViewModalOpen}
        setIsModalOpen={setIsViewModalOpen}
      />
      <DeleteBookModal
        book={activeBook}
        isModalOpen={isDeleteModalOpen}
        setIsModalOpen={setIsDeleteModalOpen}
        onOk={bookDelete}
      />
    </div>
  );
}

export default BooksPage;
