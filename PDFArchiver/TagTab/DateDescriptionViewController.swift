//
//  DateDescriptionViewController
//  PDFArchiver
//
//  Created by Julian Kahnert on 07.03.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import ArchiveLib
import PDFKit
import UIKit

class DateDescriptionViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var untaggedDocumentsCount: UILabel!
    @IBOutlet weak var documentView: PDFView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var nextButton: UIButton!

    @IBAction private func datePicker(_ sender: UIDatePicker) {
        document?.date = datePicker.date
    }

    @IBAction private func descriptionTextField(_ sender: UITextField) {
        guard let text = descriptionTextField.text else { return }
        document?.specification = text
    }

    private var suggestedTags = Set<String>()
    var document: Document? {
        didSet {
            DispatchQueue.global().async {

                // get tags and save them in the background, they will be passed to the TagViewController
                guard let path = self.document?.path,
                    let pdfDocument = PDFDocument(url: path) else { return }
                var text = ""
                for index in 0 ..< pdfDocument.pageCount {
                    guard let page = pdfDocument.page(at: index),
                        let pageContent = page.string else { return }

                    text += pageContent
                }
                self.suggestedTags = TagParser.parse(text)
            }
        }
    }

    // MARK: - View Setup
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup document view
        documentView.displayMode = .singlePageContinuous
        documentView.autoScales = true
        documentView.interpolationQuality = .low
        documentView.backgroundColor = .paLightGray

        documentView.goToFirstPage(self)
        documentView.sizeToFit()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // register keyboard notification
        registerNotifications()

        // get documents from archive
        let untaggedDocuments = DocumentService.archive.get(scope: .all, searchterms: [], status: .untagged)
        document = Array(untaggedDocuments).sorted().min()

        // update untagged documents label
        let prefix = NSLocalizedString("tagging.date-description.untagged-documents", comment: "")
        untaggedDocumentsCount.text = prefix + ": \(untaggedDocuments.count)"

        // update view with the current document state
        updateView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // show subscription view controller, if no subscription was found
        if !IAP.service.appUsagePermitted() {
            let viewController = SubscriptionViewController {
                self.tabBarController?.selectedIndex = self.tabBarController?.getViewControllerIndex(with: "ArchiveTab") ?? 2
            }
            present(viewController, animated: animated)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destinationVC = segue.destination as? TagViewController else { return }
        destinationVC.document = document
        destinationVC.suggestedTags = suggestedTags
    }

    // MARK: - Helper Functions

    private func updateView() {

        if document?.specification.starts(with: Constants.documentDescriptionPlaceholder) ?? false {
            document?.specification = ""
        }

        if let document = self.document {
            documentView.document = PDFDocument(url: document.path)
            documentView.goToFirstPage(self)
            datePicker.date = document.date
            descriptionTextField.text = document.specification
        } else {
            documentView.document = nil
            datePicker.date = Date()
            descriptionTextField.text = nil
        }
    }

    // MARK: - Keyboard Presentation

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        scrollView.contentInset.bottom = view.convert(keyboardFrame.cgRectValue, from: nil).size.height
    }

    @objc
    func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
    }
}
