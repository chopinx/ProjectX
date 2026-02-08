import UIKit

enum PDFHelper {
    /// Extracts the first page of a PDF as a UIImage
    static func extractImage(from data: Data, scale: CGFloat = 2.0) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let page = pdfDoc.page(at: 1) else { return nil }

        let pageRect = page.getBoxRect(.mediaBox)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: scale, y: -scale)
        ctx.drawPDFPage(page)

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
