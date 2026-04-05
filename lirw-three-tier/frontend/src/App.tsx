/* eslint-disable @typescript-eslint/no-explicit-any */
import { Button } from "antd";
import "./App.css";
import { Link } from "react-router-dom";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ChartData,
  ArcElement,
} from "chart.js";
import { Bar, Pie } from "react-chartjs-2";
import { useEffect, useState } from "react";
import { Book } from "./models/Books";
// import { Author } from './models/Author';

// VITE_API_URL is expected to point to the API base path (for example "/api").
// Trim a trailing slash once so endpoint construction stays predictable.
const API_URL = (import.meta.env.VITE_API_URL || "").replace(/\/$/, "");

ChartJS.register(
  ArcElement,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
);

const barChartOptions = {
  responsive: true,
  plugins: {
    legend: {
      position: "top" as const,
    },
    title: {
      display: true,
      text: "Book Length Distribution",
    },
  },
  scales: {
    y: {
      min: 150,
      max: 700,
      ticks: {
        stepSize: 10,
      },
    },
  },
};

function App() {
  const [books, setBooks] = useState<Book[]>([]);
  // const [authors, setAuthors] = useState<Author[]>([]);
  const [booksBarChartData, setBooksBarChartData] =
    useState<ChartData<"bar">>();
  // const [authorsBarChartData, setAuthorsBarChartData] = useState<ChartData<"bar">>();
  const [pieChartData, setPieChartData] = useState<ChartData<"pie">>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Load dashboard data once on first render.
    fetchBooks();
    // fetchAuthors();
  }, []);

  useEffect(() => {
    if (books.length === 0) {
      // Clear chart state when the API returns no books or a fetch failure resets the list.
      setBooksBarChartData(undefined);
      return;
    }

    const labels = books.map((book) => book.title);
    const data = books.map((book) => book.pages);

    setBooksBarChartData({
      labels,
      datasets: [
        {
          label: "Total Pages",
          data: data,
          backgroundColor: generateColors(data.length), // Adjust for desired number of colors
          borderColor: generateColors(data.length), // Adjust for desired number of colors
          borderWidth: 1,
        },
      ],
    });
  }, [books]);

  // useEffect(() => {
  //   if (authors) {
  //     const labels = authors.map(author => author.name);
  //     const data = authors.map(author => author.birthday).map(birthday => {
  //       const today = new Date();
  //       const diffInMs = today.getTime() - new Date(birthday).getTime();
  //       const age = Math.floor(diffInMs / (1000 * 60 * 60 * 24 * 365));
  //       return age;
  //     });

  //     setAuthorsBarChartData({
  //       labels,
  //       datasets: [
  //         {
  //           label: "Age",
  //           data: data,
  //           backgroundColor: 'rgba(53, 162, 235, 0.5)'
  //         }
  //       ]
  //     })
  //   }
  // }, [authors]);

  useEffect(() => {
    if (books.length === 0) {
      // Clear chart state when the API returns no books or a fetch failure resets the list.
      setPieChartData(undefined);
      return;
    }

    const authorBookCount = new Map<string, number>();

    for (const book of books) {
      const authorName = book.name;

      if (authorBookCount.has(authorName)) {
        authorBookCount.set(authorName, authorBookCount.get(authorName)! + 1);
      } else {
        authorBookCount.set(authorName, 1);
      }
    }

    const chartData = {
      labels: Array.from(authorBookCount.keys()),
      datasets: [
        {
          label: "Book Count",
          data: Array.from(authorBookCount.values()),
          backgroundColor: generateColors(authorBookCount.size), // Adjust for desired number of colors
          borderColor: generateColors(authorBookCount.size), // Adjust for desired number of colors
          borderWidth: 1,
        },
      ],
    };

    setPieChartData(chartData);
  }, [books]);

  function generateColors(numColors: number) {
    const colors = [];
    const colorPalette = [
      "#ff6384",
      "#38aecc",
      "#ffd700",
      "#4caf50",
      "#9c27b0",
    ];
    for (let i = 0; i < numColors; i++) {
      colors.push(colorPalette[i % colorPalette.length]);
    }
    return colors;
  }

  const fetchBooks = async () => {
    try {
      // Show a visible error when the frontend was deployed without an API base path.
      if (!API_URL) {
        throw new Error("VITE_API_URL is not configured.");
      }

      setLoading(true);
      setError(null);

      const response = await fetch(`${API_URL}/books`);

      // Parse failed responses as text first because ALB/proxy failures are not always JSON.
      if (!response.ok) {
        const message = await response.text();
        throw new Error(
          message || `Request failed with status ${response.status}`,
        );
      }

      const { books } = await response.json();

      // Successful API responses replace the current dataset used by both charts.
      setBooks(books);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unable to load books.";
      setError(message);
      setBooks([]);

      // Keep a console trail for debugging while also surfacing a user-facing error state.
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  // const fetchAuthors = async () => {
  //   try {
  //     const response = await fetch(`${API_URL}/authors`);
  //     const { authors, message } = await response.json();

  //     if (!response.ok) {
  //       throw new Error(message);
  //     }

  //     setAuthors(authors);
  //   } catch (error) {
  //     console.log(error);
  //   }
  // };

  return (
    <div className="h-screen font-mono p-4">
      <header className="py-2 border-b">
        <h1 className="text-center font-bold text-5xl">Dashboard</h1>
      </header>
      <main className="py-4 px-4 space-y-6">
        {loading && (
          <div className="rounded border border-slate-300 bg-slate-50 px-4 py-3 text-slate-700">
            Loading dashboard data...
          </div>
        )}
        {error && (
          <div className="rounded border border-red-300 bg-red-50 px-4 py-3 text-red-700">
            Failed to load dashboard data: {error}
          </div>
        )}
        <div className="space-x-4">
          <Button type="primary" size="large" className="rounded-none">
            <Link to={`books`}>Books</Link>
          </Button>
          <Button type="primary" size="large" className="rounded-none">
            <Link to={`authors`}>Authors</Link>
          </Button>
        </div>
        <div className="p-12 flex justify-between" style={{ height: "100%" }}>
          <div>{pieChartData && <Pie width={500} data={pieChartData} />}</div>
          <div>
            {booksBarChartData && (
              <Bar
                style={{
                  display: "block",
                  boxSizing: "border-box",
                  height: "500px",
                  width: "900px",
                }}
                width={1800}
                height={900}
                options={barChartOptions}
                data={booksBarChartData}
              />
            )}
          </div>
          {/* <div>
            {authorsBarChartData && (<Bar width={700} options={barChartOptions} data={authorsBarChartData} />)}
          </div> */}
        </div>
      </main>
    </div>
  );
}

export default App;
