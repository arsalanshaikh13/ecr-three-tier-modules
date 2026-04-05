const dbPromise = require("../configs/db");
const logger = require("../utils/logger"); // Import logger

function BooksController() {}

const getQuery = `SELECT b.id as id, b.title as title, b.releaseDate as releaseDate, b.description as description, b.pages as pages,
 b.createdAt as createdAt, b.updatedAt as updatedAt, a.id as authorId, a.name as name, a.birthday as birthday, a.bio as bio FROM book b INNER JOIN author a on b.authorId = a.id`;

BooksController.prototype.get = async (req, res) => {
  try {
    logger.info("BooksController [GET]");

    // Resolve the pool inside each handler so requests do not depend on module-load timing.
    const db = await dbPromise;
    const [books] = await db.query(getQuery);

    logger.info(`Books count: ${books.length}`);

    return res.status(200).json({
      books,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

BooksController.prototype.create = async (req, res) => {
  try {
    const { title, description, releaseDate, pages, author: authorId } = req.body;
    const parsedReleaseDate = new Date(releaseDate);

    // Reject invalid user input before it reaches the database layer.
    if (!releaseDate || Number.isNaN(parsedReleaseDate.getTime())) {
      return res.status(400).json({
        message: "Invalid releaseDate format.",
      });
    }

    logger.info(
      `BooksController [CREATE] - title: ${title}, description: ${description}, releaseDate: ${releaseDate}, pages: ${pages}, authorId: ${authorId}`,
    );

    const db = await dbPromise;
    await db.query(
      "INSERT INTO book (title, releaseDate, description, pages, authorId, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [title, parsedReleaseDate, description, pages, authorId, new Date(), new Date()],
    );
    // Re-read the collection after writes so the UI gets the latest book list.
    const [books] = await db.query(getQuery);

    logger.info(`Book created successfully. books count: ${books.length}`);

    return res.status(201).json({
      message: "Book created successfully!",
      books,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

BooksController.prototype.update = async (req, res) => {
  try {
    const bookId = req.params.id;
    const { title, description, releaseDate, pages, author: authorId } = req.body;
    const parsedReleaseDate = new Date(releaseDate);

    if (!releaseDate || Number.isNaN(parsedReleaseDate.getTime())) {
      return res.status(400).json({
        message: "Invalid releaseDate format.",
      });
    }

    logger.info(
      `BooksController [UPDATE] - title: ${title}, description: ${description}, releaseDate: ${releaseDate}, pages: ${pages}, authorId: ${authorId}`,
    );

    const db = await dbPromise;
    const [result] = await db.query(
      "UPDATE book SET title = ?, releaseDate = ?, description = ?, pages = ?, authorId = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?",
      [title, parsedReleaseDate, description, pages, authorId, bookId],
    );

    // Return a clear not-found response instead of reporting a silent no-op update.
    if (result.affectedRows === 0) {
      return res.status(404).json({
        message: "Book not found.",
      });
    }

    const [books] = await db.query(getQuery);

    logger.info(`Book updated successfully. books count: ${books.length}`);

    return res.status(200).json({
      message: "Book updated successfully!",
      books,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

BooksController.prototype.delete = async (req, res) => {
  try {
    const bookId = req.params.id;

    logger.info(`BooksController [DELETE] - bookId: ${bookId}`);

    // Use the shared pool for deletes too so all CRUD paths behave consistently.
    const db = await dbPromise;
    const [result] = await db.query("DELETE FROM book WHERE id = ?", [bookId]);

    // Return a clear not-found response instead of reporting a silent no-op delete.
    if (result.affectedRows === 0) {
      return res.status(404).json({
        message: "Book not found.",
      });
    }

    const [books] = await db.query(getQuery);

    logger.info(`Book deleted successfully. books count: ${books.length}`);

    return res.status(200).json({
      message: "Book deleted successfully!",
      books,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

module.exports = new BooksController();
