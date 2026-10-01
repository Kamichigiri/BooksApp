import 'package:books_app/domain/models/books.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Book Model Tests', () {
    test('Book serialisation and deserialisation works properly', () {
      const book = Book(
        id: 1,
        name: 'The Great Odyssey',
        author: 'Homer',
        category: 'Classics',
        rating: 4.8,
        currentPage: 5,
        numberOfPages: 20,
      );

      final map = book.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'The Great Odyssey');
      expect(map['current_page'], 5);
      expect(map['number_of_pages'], 20);

      final fromMap = Book.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.title, 'The Great Odyssey');
      expect(fromMap.name, 'The Great Odyssey');
      expect(fromMap.author, 'Homer');
      expect(fromMap.category, 'Classics');
      expect(fromMap.currentPage, 5);
      expect(fromMap.numberOfPages, 20);
      expect(fromMap.progressPercentage, 0.25);
      expect(fromMap.isInProgress, true);
    });

    test('Bookmark serialisation and deserialisation works properly', () {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 10,
        bookId: 1,
        text: 'A profound quote',
        textColor: BookmarkColor.blue,
        page: 4,
        createdAt: now,
      );

      final map = bookmark.toMap();
      expect(map['id'], 10);
      expect(map['book_id'], 1);
      expect(map['text'], 'A profound quote');
      expect(map['page'], 4);

      final fromMap = Bookmark.fromMap(map);
      expect(fromMap.id, 10);
      expect(fromMap.bookId, 1);
      expect(fromMap.note, 'A profound quote');
      expect(fromMap.color, BookmarkColor.blue);
      expect(fromMap.page, 4);
    });
  });
}
