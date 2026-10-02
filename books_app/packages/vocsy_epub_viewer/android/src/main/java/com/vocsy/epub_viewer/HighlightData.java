package com.vocsy.epub_viewer;

import com.folioreader.model.HighLight;

import java.util.Date;

/**
 * Class contain data structure for highlight data. If user want to
 * provide external highlight data to folio activity. class should implement to
 * {@link HighLight} with contains required members.
 * <p>
 * Created by gautam chibde on 12/10/17.
 */

public class HighlightData implements HighLight {

    private String bookId;
    private String content;
    private Date date;
    private String type;
    private int pageNumber;
    private String pageId;
    private String rangy;
    private String uuid;
    private String note;

    /**
     * Returns a diagnostic representation of all stored highlight fields.
     */
    @Override
    public String toString() {
        return "HighlightData{" +
                "bookId='" + bookId + '\'' +
                ", content='" + content + '\'' +
                ", date=" + date +
                ", type='" + type + '\'' +
                ", pageNumber=" + pageNumber +
                ", pageId='" + pageId + '\'' +
                ", rangy='" + rangy + '\'' +
                ", uuid='" + uuid + '\'' +
                ", note='" + note + '\'' +
                '}';
    }

    /**
     * Returns the identifier of the book containing the highlight.
     */
    @Override
    public String getBookId() {
        return bookId;
    }

    /**
     * Returns the highlighted text.
     */
    @Override
    public String getContent() {
        return content;
    }

    /**
     * Returns the stored highlight date.
     */
    @Override
    public Date getDate() {
        return date;
    }

    /**
     * Returns the stored highlight type.
     */
    @Override
    public String getType() {
        return type;
    }

    /**
     * Returns the page number associated with the highlight.
     */
    @Override
    public int getPageNumber() {
        return pageNumber;
    }

    /**
     * Returns the identifier of the page containing the highlight.
     */
    @Override
    public String getPageId() {
        return pageId;
    }

    /**
     * Returns the serialized Rangy selection range.
     */
    @Override
    public String getRangy() {
        return rangy;
    }

    /**
     * Returns the unique identifier of the highlight.
     */
    @Override
    public String getUUID() {
        return uuid;
    }

    /**
     * Returns the note attached to the highlight.
     */
    @Override
    public String getNote() {
        return note;
    }
}
