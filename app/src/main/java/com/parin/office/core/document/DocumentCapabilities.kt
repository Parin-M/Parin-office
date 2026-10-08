package com.parin.office.core.document

enum class DocumentCapability {
    VIEW, TEXT_SELECTION, SEARCH, EDIT_TEXT, EDIT_STYLE, EDIT_LAYOUT,
    TABLES, FORMULAS, CHARTS, IMAGES, COMMENTS, TRACK_CHANGES,
    ANNOTATIONS, FORMS, SIGNATURES, PRINT_LAYOUT, PRESENT, EXPORT
}

data class CapabilitySet(private val values: Set<DocumentCapability>) {
    operator fun contains(value: DocumentCapability) = value in values
    fun asSet() = values

    companion object {
        val PDF = CapabilitySet(setOf(
            DocumentCapability.VIEW, DocumentCapability.TEXT_SELECTION,
            DocumentCapability.SEARCH, DocumentCapability.ANNOTATIONS,
            DocumentCapability.FORMS, DocumentCapability.SIGNATURES,
            DocumentCapability.EXPORT
        ))

        val WORD = CapabilitySet(setOf(
            DocumentCapability.VIEW, DocumentCapability.TEXT_SELECTION,
            DocumentCapability.SEARCH, DocumentCapability.EDIT_TEXT,
            DocumentCapability.EDIT_STYLE, DocumentCapability.EDIT_LAYOUT,
            DocumentCapability.TABLES, DocumentCapability.IMAGES,
            DocumentCapability.COMMENTS, DocumentCapability.TRACK_CHANGES,
            DocumentCapability.PRINT_LAYOUT, DocumentCapability.EXPORT
        ))

        val POWERPOINT = CapabilitySet(setOf(
            DocumentCapability.VIEW, DocumentCapability.TEXT_SELECTION,
            DocumentCapability.SEARCH, DocumentCapability.EDIT_TEXT,
            DocumentCapability.EDIT_STYLE, DocumentCapability.EDIT_LAYOUT,
            DocumentCapability.TABLES, DocumentCapability.IMAGES,
            DocumentCapability.PRESENT, DocumentCapability.ANNOTATIONS,
            DocumentCapability.EXPORT
        ))

        val EXCEL = CapabilitySet(setOf(
            DocumentCapability.VIEW, DocumentCapability.TEXT_SELECTION,
            DocumentCapability.SEARCH, DocumentCapability.EDIT_TEXT,
            DocumentCapability.EDIT_STYLE, DocumentCapability.EDIT_LAYOUT,
            DocumentCapability.TABLES, DocumentCapability.FORMULAS,
            DocumentCapability.CHARTS, DocumentCapability.IMAGES,
            DocumentCapability.PRINT_LAYOUT, DocumentCapability.EXPORT
        ))
    }
}
