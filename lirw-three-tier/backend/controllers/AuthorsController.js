const dbPromise = require("../configs/db");
const logger = require("../utils/logger"); // Import logger

function AuthorsController() {}

const getQuery = "SELECT * FROM author";

AuthorsController.prototype.get = async (req, res) => {
  try {
    logger.info("AuthorsController [GET]");

    // Resolve the pool inside each handler so requests do not depend on module-load timing.
    const db = await dbPromise;
    const [authors] = await db.query(getQuery);

    logger.info(`Authors count: ${authors.length}`);

    return res.status(200).json({
      authors,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

AuthorsController.prototype.create = async (req, res) => {
  try {
    const { name, birthday, bio } = req.body;
    const parsedBirthday = new Date(birthday);

    // Validate birthday before sending it to MySQL so invalid dates fail fast.
    if (!birthday || Number.isNaN(parsedBirthday.getTime())) {
      return res.status(400).json({
        message: "Invalid birthday format.",
      });
    }

    logger.info(
      `AuthorsController [CREATE] - name: ${name}, birthday: ${birthday}, bio: ${bio}`,
    );

    const db = await dbPromise;
    await db.query(
      "INSERT INTO author (name, birthday, bio, createdAt, updatedAt) VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      [name, parsedBirthday, bio],
    );
    // Re-read the collection after writes so the UI gets the latest author list.
    const [authors] = await db.query(getQuery);

    logger.info(`Author created successfully. authors count: ${authors.length}`);

    return res.status(201).json({
      message: "Author created successfully!",
      authors,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

AuthorsController.prototype.update = async (req, res) => {
  try {
    const authorId = req.params.id;
    const { name, birthday, bio } = req.body;
    const parsedBirthday = new Date(birthday);

    // Reject invalid user input before it reaches the database layer.
    if (!birthday || Number.isNaN(parsedBirthday.getTime())) {
      return res.status(400).json({
        message: "Invalid birthday format.",
      });
    }

    logger.info(
      `AuthorsController [UPDATE] - authorId: ${authorId}, name: ${name}, birthday: ${birthday}, bio: ${bio}`,
    );

    const db = await dbPromise;
    const [result] = await db.query(
      "UPDATE author SET name = ?, birthday = ?, bio = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?",
      [name, parsedBirthday, bio, authorId],
    );

    // Return a clear not-found response instead of reporting a silent no-op update.
    if (result.affectedRows === 0) {
      return res.status(404).json({
        message: "Author not found.",
      });
    }

    const [authors] = await db.query(getQuery);

    logger.info(`Author updated successfully. authors count: ${authors.length}`);

    return res.status(200).json({
      message: "Author updated successfully!",
      authors,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

AuthorsController.prototype.delete = async (req, res) => {
  try {
    const authorId = req.params.id;

    logger.info(`AuthorsController [DELETE] - authorId: ${authorId}`);

    // Use the shared pool for deletes too so all CRUD paths behave consistently.
    const db = await dbPromise;
    const [result] = await db.query("DELETE FROM author WHERE id = ?", [authorId]);

    // Return a clear not-found response instead of reporting a silent no-op delete.
    if (result.affectedRows === 0) {
      return res.status(404).json({
        message: "Author not found.",
      });
    }

    const [authors] = await db.query(getQuery);

    logger.info(`Author deleted successfully. authors count: ${authors.length}`);

    return res.status(200).json({
      message: "Author deleted successfully!",
      authors,
    });
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return res.status(500).json({
      message: "Something unexpected has happened. Please try again later.",
    });
  }
};

module.exports = new AuthorsController();
