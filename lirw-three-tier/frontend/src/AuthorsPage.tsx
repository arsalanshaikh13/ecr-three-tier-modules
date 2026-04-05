import { Alert, Button, Table } from "antd";
import "./App.css";
import { useEffect, useState } from "react";
import { IconEdit } from "./components/IconEdit";
import { IconDelete } from "./components/IconDelete";
import { IconView } from "./components/IconView";
import { Link } from "react-router-dom";
import { Author } from "./models/Author";
import { AddEditAuthorModal } from "./components/AddEditAuthorModal";
import { ViewAuthorModal } from "./components/ViewAuthorModal";
import { DeleteAuthorModal } from "./components/DeleteAuthorModal";

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
    title: "Author",
    dataIndex: "name",
    key: "name",
  },
  {
    title: "Birthday",
    dataIndex: "birthday",
    key: "birthday",
  },
  {
    title: "Description",
    dataIndex: "bio",
    key: "bio",
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

type AuthorsResponse = {
  authors: Author[];
  message?: string;
};

function AuthorsPage() {
  const [authors, setAuthors] = useState<Author[]>([]);
  const [dataSource, setDataSource] = useState<Author[]>([]);
  const [activeAuthor, setActiveAuthor] = useState<Author>();
  const [isAddEditModalOpen, setIsAddEditModalOpen] = useState(false);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isSuccessAlertVisible, setIsSuccessAlertVisible] = useState(false);
  const [isErrorAlertVisible, setIsErrorAlertVisible] = useState(false);
  const [message, setMessage] = useState("");
  const [isEdit, setIsEdit] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Load authors once on first render so table and modals share the same source of truth.
    fetchAuthors();
  }, []);

  useEffect(() => {
    // Rebuild the table rows whenever the canonical authors list changes.
    formatAuthorsForDisplay(authors);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authors]);

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

  const fetchAuthors = async () => {
    try {
      if (!API_URL) {
        throw new Error("VITE_API_URL is not configured.");
      }

      // Table loading state makes backend failures visible instead of leaving the page looking idle.
      setLoading(true);
      const response = await requestJson<AuthorsResponse>(`${API_URL}/authors`);
      setAuthors(response.authors);
    } catch (error) {
      console.error(error);
      setAuthors([]);
      showAlert(extractErrorMessage(error), "error");
    } finally {
      setLoading(false);
    }
  };

  const editAuthor = async (author: Author) => {
    try {
      if (activeAuthor) {
        const response = await requestJson<AuthorsResponse>(
          `${API_URL}/authors/${activeAuthor.id}`,
          {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(author),
          },
        );

        setAuthors(response.authors);
        showAlert(
          response.message || "Author updated successfully!",
          "success",
        );
      }
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const addAuthor = async (author: Author) => {
    try {
      const response = await requestJson<AuthorsResponse>(
        `${API_URL}/authors`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify(author),
        },
      );

      setAuthors(response.authors);
      showAlert(response.message || "Author created successfully!", "success");
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const authorAddEdit = (author: Author) => {
    // Reuse one submit path for create/edit so modal wiring stays simple.
    if (isEdit) {
      editAuthor(author);
      return;
    }

    addAuthor(author);
  };

  const authorDelete = async () => {
    try {
      if (activeAuthor) {
        const response = await requestJson<AuthorsResponse>(
          `${API_URL}/authors/${activeAuthor.id}`,
          {
            method: "DELETE",
            headers: {
              "Content-Type": "application/json",
            },
          },
        );

        setAuthors(response.authors);
        showAlert(
          response.message || "Author deleted successfully!",
          "success",
        );
      }
    } catch (error) {
      console.error(error);
      showAlert(extractErrorMessage(error), "error");
    }
  };

  const handleAuthorAdd = () => {
    // Reset the active record before opening the modal in create mode.
    setActiveAuthor(undefined);
    setIsEdit(false);
    setIsAddEditModalOpen(true);
  };

  const handleAuthorEdit = (author: Author) => {
    setActiveAuthor(author);
    setIsEdit(true);
    setIsAddEditModalOpen(true);
  };

  const handleAuthorView = (author: Author) => {
    setActiveAuthor(author);
    setIsViewModalOpen(true);
  };

  const handleAuthorDelete = (author: Author) => {
    setActiveAuthor(author);
    setIsDeleteModalOpen(true);
  };

  const formatAuthorsForDisplay = (nextAuthors: Author[]) => {
    // Clear stale rows when the API returns an empty list or a request fails.
    if (nextAuthors.length === 0) {
      setDataSource([]);
      return;
    }

    const nextDataSource = [];

    for (const author of nextAuthors) {
      const authorObj = {
        key: author.id,
        id: author.id,
        name: author.name,
        birthday: author.birthday,
        bio: author.bio,
        createdAt: author.createdAt,
        updatedAt: author.updatedAt,
        actions: (
          <div className="flex space-x-4">
            <Button
              icon={<IconEdit />}
              onClick={() => handleAuthorEdit(author)}
            />
            <Button
              type="primary"
              icon={<IconView />}
              onClick={() => handleAuthorView(author)}
            />
            <Button
              type="primary"
              icon={<IconDelete />}
              danger
              onClick={() => handleAuthorDelete(author)}
            />
          </div>
        ),
      };

      nextDataSource.push(authorObj);
    }

    setDataSource(nextDataSource);
  };

  return (
    <div className="h-screen font-mono p-4">
      <header className="relative py-2 border-b">
        <Button size="large" className="rounded-none absolute">
          <Link to={`/`}>Dashboard</Link>
        </Button>
        <h1 className="text-center font-bold text-5xl">MANAGE AUTHORS</h1>
      </header>
      <main className="py-4 px-4 space-y-6">
        <div className="flex justify-between">
          <Button
            type="primary"
            size="large"
            className="rounded-none"
            onClick={handleAuthorAdd}
          >
            <span className="font-bold">+</span>&nbsp; Add Author
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
      <AddEditAuthorModal
        initialValues={activeAuthor}
        isEdit={isEdit}
        isModalOpen={isAddEditModalOpen}
        setIsModalOpen={setIsAddEditModalOpen}
        onOk={authorAddEdit}
      />
      <ViewAuthorModal
        author={activeAuthor}
        isModalOpen={isViewModalOpen}
        setIsModalOpen={setIsViewModalOpen}
      />
      <DeleteAuthorModal
        author={activeAuthor}
        isModalOpen={isDeleteModalOpen}
        setIsModalOpen={setIsDeleteModalOpen}
        onOk={authorDelete}
      />
    </div>
  );
}

export default AuthorsPage;
