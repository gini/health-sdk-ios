//
//  PaymentReviewViewController.swift
//  GiniHealth
//
//  Created by Nadya Karaban on 30.03.21.
//

import UIKit
import GiniHealthAPILibrary

public final class PaymentReviewViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet weak var pageControlHeightConstraint: NSLayoutConstraint!
    @IBOutlet var recipientField: UITextField!
    @IBOutlet var ibanField: UITextField!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var usageField: UITextField!
    @IBOutlet var payButton: GiniCustomButton!
    @IBOutlet var paymentInputFieldsErrorLabels: [UILabel]!
    @IBOutlet var usageErrorLabel: UILabel!
    @IBOutlet var amountErrorLabel: UILabel!
    @IBOutlet var ibanErrorLabel: UILabel!
    @IBOutlet var recipientErrorLabel: UILabel!
    @IBOutlet var paymentInputFields: [UITextField]!
    @IBOutlet var bankProviderButtonView: UIView!
    @IBOutlet weak var bankProviderLabel: UILabel!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet var inputContainer: UIView!
    @IBOutlet var containerCollectionView: UIView!
    @IBOutlet var paymentInfoStackView: UIStackView!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var bankProviderEditIcon: UIImageView!
    
    @IBOutlet weak var bankProviderImage: UIImageView!
    @IBOutlet weak var infoBar: UIView!
    @IBOutlet weak var infoBarLabel: UILabel!
    var model: PaymentReviewModel?
    var paymentProviders: [PaymentProvider] = []
    private var amountToPay = Price(value: 0, currencyCode: "EUR")
    private var lastValidatedIBAN = ""
    
    private var selectedPaymentProvider: PaymentProvider? {
        didSet {
            if let provider = selectedPaymentProvider {
                DispatchQueue.main.async {
                    self.updateUIWithDefaultPaymentProvider(provider: provider)
                }
            }
        }
    }
    
    public weak var trackingDelegate: GiniHealthTrackingDelegate?
    
    enum TextFieldType: Int {
        case recipientFieldTag = 1
        case ibanFieldTag
        case amountFieldTag
        case usageFieldTag
    }
    
    public static func instantiate(with giniHealth: GiniHealth, document: Document, extractions: [Extraction], trackingDelegate: GiniHealthTrackingDelegate? = nil) -> PaymentReviewViewController {
        let vc = (UIStoryboard(name: "PaymentReview", bundle: giniHealthBundle())
            .instantiateViewController(withIdentifier: "paymentReviewViewController") as? PaymentReviewViewController)!
        vc.model = PaymentReviewModel(with: giniHealth, document: document, extractions: extractions )
        vc.trackingDelegate = trackingDelegate
        return vc
    }
    
    public static func instantiate(with giniHealth: GiniHealth, data: DataForReview, trackingDelegate: GiniHealthTrackingDelegate? = nil) -> PaymentReviewViewController {
        let vc = (UIStoryboard(name: "PaymentReview", bundle: giniHealthBundle())
            .instantiateViewController(withIdentifier: "paymentReviewViewController") as? PaymentReviewViewController)!
        vc.model = PaymentReviewModel(with: giniHealth, document: data.document, extractions: data.extractions)
        vc.trackingDelegate = trackingDelegate
        return vc
    }

    var giniHealthConfiguration = GiniHealthConfiguration.shared
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        subscribeOnNotifications()
        dismissKeyboardOnTap()
        configureUI()
        setupViewModel()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showInfoBar()
    }
    
    fileprivate func setupViewModel() {
        
        model?.onNoAppsErrorHandling = {[weak self] error in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginihealth.errors.no.banking.app.installed",
                                                                         comment: "no bank apps installed") )
            }
        }
        
        model?.onExtractionFetched = { [weak self] () in
            DispatchQueue.main.async {
                self?.fillInInputFields()
            }
        }
        
        model?.onPaymentProvidersFetched = {[weak self] providers in
            DispatchQueue.main.async { [weak self] in
                self?.paymentProviders.append(contentsOf: providers)
                if let paymentProviders = self?.paymentProviders, paymentProviders.count > 0 {
                    let providerId = UserDefaults.standard.string(forKey: "ginihealth.defaultPaymentProviderId")
                    let provider = paymentProviders.first(where: { $0.id == providerId }) ?? paymentProviders[0]
                    self?.selectedPaymentProvider = provider
                }
            }
        }
        
        model?.checkIfAnyPaymentProviderAvailable()

        
        model?.updateImagesLoadingStatus = { [weak self] () in
            DispatchQueue.main.async { [weak self] in
                let isLoading = self?.model?.isImagesLoading ?? false
                if isLoading {
                    self?.collectionView.showLoading(style: self?.giniHealthConfiguration.loadingIndicatorStyle, color: UIColor.from(giniColor: self?.giniHealthConfiguration.loadingIndicatorColor ?? GiniHealthConfiguration.shared.loadingIndicatorColor), scale: self?.giniHealthConfiguration.loadingIndicatorScale)
                } else {
                    self?.collectionView.stopLoading()
                }
            }
        }
       
        model?.updateLoadingStatus = { [weak self] () in
            DispatchQueue.main.async { [weak self] in
                let isLoading = self?.model?.isLoading ?? false
                if isLoading {
                    self?.view.showLoading(style: self?.giniHealthConfiguration.loadingIndicatorStyle, color: UIColor.from(giniColor: self?.giniHealthConfiguration.loadingIndicatorColor ?? GiniHealthConfiguration.shared.loadingIndicatorColor), scale: self?.giniHealthConfiguration.loadingIndicatorScale)
                } else {
                    self?.view.stopLoading()
                }
            }
        }
            
       model?.reloadCollectionViewClosure = { [weak self] () in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }
        
        model?.onPreviewImagesFetched = { [weak self] () in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }
        
        model?.onErrorHandling = {[weak self] error in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginihealth.errors.default",
                                                                         comment: "default error message") )
            }
        }
        
        model?.onBankSelection = {[weak self] provider in
            DispatchQueue.main.async {
                self?.updateUIWithDefaultPaymentProvider(provider: provider)
            }
        }
        
        model?.onCreatePaymentRequestErrorHandling = {[weak self] () in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginihealth.errors.failed.payment.request.creation",
                                                                      comment: "error for creating payment request"))
            }
        }
        
        model?.fetchImages()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        unsubscribeFromNotifications()
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        inputContainer.roundCorners(corners: [.topLeft, .topRight], radius: 12)
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return giniHealthConfiguration.paymentReviewStatusBarStyle
    }
    
    // MARK: - congifureUI

    fileprivate func configureUI() {
        configureScreenBackgroundColor()
        configureCollectionView()
        configurePaymentInputFields()
        configurePageControl()
        configureCloseButton()
        configurePayButtonInitialState()
        hideErrorLabels()
        fillInInputFields()
        addDoneButtonForNumPad(amountField)
    }
    
    // MARK: - Info bar

    fileprivate func configureInfoBar() {
        infoBar.roundCorners(corners: [.topLeft, .topRight], radius: giniHealthConfiguration.infoBarCornerRadius)
        infoBar.backgroundColor = UIColor.from(giniColor: giniHealthConfiguration.infoBarBackgroundColor)
        infoBarLabel.textColor = UIColor.from(giniColor: giniHealthConfiguration.infoBarTextColor)
        infoBarLabel.font = giniHealthConfiguration.customFont.regular
        infoBarLabel.adjustsFontForContentSizeCategory = true
        infoBarLabel.text = NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.infobar.message",
                                                             comment: "info bar message")
    }
    
    fileprivate func showInfoBar() {
        configureInfoBar()
        infoBar.isHidden = false
        let screenSize = UIScreen.main.bounds.size
        UIView.animate(withDuration: 0.5,
                       delay: 0, usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 1.0,
                       options: [], animations: {
                           self.infoBar.frame = CGRect(x: 0, y: self.inputContainer.frame.minY + self.giniHealthConfiguration.infoBarCornerRadius - self.infoBar.frame.height, width: screenSize.width, height: self.infoBar.frame.height)
                       }, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.animateSlideDownInfoBar()
        }
    }
    
    fileprivate func animateSlideDownInfoBar() {
        let screenSize = UIScreen.main.bounds.size
        UIView.animate(withDuration: 0.5,
                       delay: 0, usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 1.0,
                       options: [], animations: {
                           self.infoBar.frame = CGRect(x: 0, y: self.inputContainer.frame.minY, width: screenSize.width, height: self.infoBar.frame.height)
                       }, completion: { _ in
                           self.infoBar.isHidden = true
                       })
    }

    // MARK: - ConfigureBankProviderView
    
    fileprivate func configureBankProviderView(paymentProvider: PaymentProvider) {
        bankProviderButtonView.backgroundColor = UIColor.from(giniColor: giniHealthConfiguration.bankButtonBackgroundColor)
        bankProviderButtonView.layer.cornerRadius = giniHealthConfiguration.bankButtonCornerRadius
        bankProviderButtonView.layer.borderWidth = giniHealthConfiguration.bankButtonBorderWidth
        bankProviderButtonView.layer.borderColor = UIColor.from(giniColor: giniHealthConfiguration.bankButtonBorderColor).cgColor

        bankProviderLabel.textColor = UIColor.from(giniColor: giniHealthConfiguration.bankButtonTextColor)
        bankProviderLabel.text = paymentProvider.name

        let imageData =  paymentProvider.iconData
        if let image = UIImage(data: imageData){
            bankProviderImage.image = image
        }
        
        if let templateImage = UIImageNamedPreferred(named: "editIcon"), self.paymentProviders.count > 1 {
            bankProviderEditIcon.image = templateImage.withRenderingMode(.alwaysTemplate)
            bankProviderEditIcon.tintColor = UIColor.from(giniColor: giniHealthConfiguration.bankButtonEditIconColor)
            let selectProviderTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(selectBankProviderTapped))
            bankProviderButtonView.addGestureRecognizer(selectProviderTapRecognizer)
        }
        bankProviderLabel.font = giniHealthConfiguration.customFont.regular
        bankProviderLabel.adjustsFontForContentSizeCategory = true

    }
    
    fileprivate func updateUIWithDefaultPaymentProvider(provider: PaymentProvider){
        self.configureBankProviderView(paymentProvider: provider)
        self.configurePayButton(paymentProvider: provider)
    }

    fileprivate func presentBankSelectionViewController() {
       
       let availableProviders = self.paymentProviders
        if availableProviders.count > 1 {
            let bankSelectionViewController = BankProviderViewController.instantiate(with: availableProviders)
            bankSelectionViewController.onSelectedProviderDidChanged = { provider in
                self.selectedPaymentProvider = provider
            }
            bankSelectionViewController.modalPresentationStyle = .overCurrentContext
            bankSelectionViewController.modalTransitionStyle = .crossDissolve
            present(bankSelectionViewController, animated: true)
        }
    }

    fileprivate func configurePayButton(paymentProvider: PaymentProvider) {
        let backgroundColorString = String.rgbaHexFrom(rgbHex: paymentProvider.colors.background)
        if let backgroundHexColor = UIColor(hex: backgroundColorString) {
            payButton.defaultBackgroundColor  = UIColor.from(giniColor: GiniColor(lightModeColor: backgroundHexColor, darkModeColor: backgroundHexColor))
        }
        let textColorString = String.rgbaHexFrom(rgbHex: paymentProvider.colors.text)
        if let textHexColor = UIColor(hex: textColorString) {
            payButton.textColor = UIColor.from(giniColor: GiniColor(lightModeColor: textHexColor, darkModeColor: textHexColor))
        }
        disablePayButtonIfNeeded()
    }
    
    fileprivate func configurePayButtonInitialState() {
        payButton.disabledBackgroundColor = UIColor.from(giniColor: giniHealthConfiguration.payButtonDisabledBackgroundColor)
        payButton.isEnabled = false
        payButton.disabledTextColor = UIColor.from(giniColor: giniHealthConfiguration.payButtonDisabledTextColor)
        payButton.layer.cornerRadius = giniHealthConfiguration.payButtonCornerRadius
        payButton.titleLabel?.font = giniHealthConfiguration.payButtonTitleFont
        payButton.setTitle( NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.next.button.title",
                                                             comment: "next button title"), for: .normal)
    }
    
    fileprivate func configurePaymentInputFields() {
        for field in paymentInputFields {
            applyDefaultStyle(field)
        }
    }
    
    fileprivate func configureCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    fileprivate func configurePageControl() {
        pageControl.layer.zPosition = 10
        pageControl.pageIndicatorTintColor = UIColor.from(giniColor:giniHealthConfiguration.pageIndicatorTintColor)
        pageControl.currentPageIndicatorTintColor = UIColor.from(giniColor:giniHealthConfiguration.currentPageIndicatorTintColor)
        pageControl.hidesForSinglePage = true
        pageControl.numberOfPages = model?.document.pageCount ?? 1
        if pageControl.numberOfPages == 1 {
            pageControlHeightConstraint.constant = 0
        } else {
            pageControlHeightConstraint.constant = 20
        }
    }
    
    fileprivate func configureCloseButton() {
        closeButton.isHidden = !giniHealthConfiguration.showPaymentReviewCloseButton
        closeButton.setImage(UIImageNamedPreferred(named: "paymentReviewCloseButton"), for: .normal)
    }
    
    fileprivate func configureScreenBackgroundColor() {
        let screenBackgroundColor = UIColor.from(giniColor:giniHealthConfiguration.paymentScreenBackgroundColor)
        mainView.backgroundColor = screenBackgroundColor
        collectionView.backgroundColor = screenBackgroundColor
        pageControl.backgroundColor = screenBackgroundColor
        inputContainer.backgroundColor = UIColor.from(giniColor:giniHealthConfiguration.inputFieldsContainerBackgroundColor)
    }
    
    // MARK: - Input fields configuration

    fileprivate func applyDefaultStyle(_ field: UITextField) {
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: field.frame.height))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: field.frame.height))
        field.rightViewMode = .always
        field.layer.cornerRadius = self.giniHealthConfiguration.paymentInputFieldCornerRadius
        field.layer.borderWidth = giniHealthConfiguration.paymentInputFieldBorderWidth
        field.backgroundColor = UIColor.from(giniColor: giniHealthConfiguration.paymentInputFieldBackgroundColor)
        field.font = giniHealthConfiguration.customFont.regular
        field.textColor = UIColor.from(giniColor: giniHealthConfiguration.paymentInputFieldTextColor)
        let placeholderText = inputFieldPlaceholderText(field)
        field.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: [NSAttributedString.Key.foregroundColor: UIColor.from(giniColor: giniHealthConfiguration.paymentInputFieldPlaceholderTextColor), NSAttributedString.Key.font: giniHealthConfiguration.customFont.regular])
        field.layer.masksToBounds = true
    }

    fileprivate func applyErrorStyle(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            textField.layer.cornerRadius = self.giniHealthConfiguration.paymentInputFieldCornerRadius
            textField.backgroundColor = UIColor.from(giniColor: self.giniHealthConfiguration.paymentInputFieldBackgroundColor)
            textField.layer.borderWidth = self.giniHealthConfiguration.paymentInputFieldErrorStyleBorderWidth
            textField.layer.borderColor = UIColor.from(giniColor: self.giniHealthConfiguration.paymentInputFieldErrorStyleColor).cgColor
            textField.layer.masksToBounds = true
        }
    }

    fileprivate func applySelectionStyle(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            textField.layer.cornerRadius = self.giniHealthConfiguration.paymentInputFieldCornerRadius
            textField.backgroundColor = UIColor.from(giniColor: self.giniHealthConfiguration.paymentInputFieldSelectionBackgroundColor)
            textField.layer.borderWidth = self.giniHealthConfiguration.paymentInputFieldSelectionStyleBorderWidth
            textField.layer.borderColor = UIColor.from(giniColor: self.giniHealthConfiguration.paymentInputFieldSelectionStyleColor).cgColor
            textField.layer.masksToBounds = true
        }
    }
    
    @objc fileprivate func doneWithAmountInputButtonTapped() {
        amountField.endEditing(true)
        amountField.resignFirstResponder()
        
        if amountField.hasText && !amountField.isReallyEmpty {
            updateAmoutToPayWithCurrencyFormat()
        }
    }

     func addDoneButtonForNumPad(_ textField: UITextField) {
        let toolbarDone = UIToolbar(frame:CGRect(x:0, y:0, width:view.frame.width, height:40))
        toolbarDone.sizeToFit()
        let flexBarButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let barBtnDone = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.done,
                                              target: self, action: #selector(PaymentReviewViewController.doneWithAmountInputButtonTapped))
        
        toolbarDone.items = [flexBarButton, barBtnDone]
        textField.inputAccessoryView = toolbarDone
    }
    
    fileprivate func inputFieldPlaceholderText(_ textField: UITextField) -> String {
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            switch fieldIdentifier {
            case .recipientFieldTag:
                return NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.recipient.placeholder",
                                                        comment: "placeholder text for recipient input field")
            case .ibanFieldTag:
                return NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.iban.placeholder",
                                                        comment: "placeholder text for iban input field")
            case .amountFieldTag:
                return NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.amount.placeholder",
                                                        comment: "placeholder text for amount input field")
            case .usageFieldTag:
                return NSLocalizedStringPreferredFormat("ginihealth.reviewscreen.usage.placeholder",
                                                        comment: "placeholder text for usage input field")
            }
        }
        return ""
    }
    
    // MARK: - Input fields validation
    
    @IBAction func textFieldChanged(_ sender: UITextField) {
        disablePayButtonIfNeeded()
    }
    
    fileprivate func validateTextField(_ textField: UITextField) {
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            switch fieldIdentifier {
            case .amountFieldTag:
                if amountField.hasText && !amountField.isReallyEmpty  {
                    let decimalPart = amountToPay.value
                    if decimalPart > 0 {
                        applyDefaultStyle(textField)
                        hideErrorLabel(textFieldTag: fieldIdentifier)
                    } else {
                        amountField.text = ""
                        applyErrorStyle(textField)
                        showErrorLabel(textFieldTag: fieldIdentifier)
                    }
                } else {
                    applyErrorStyle(textField)
                    showErrorLabel(textFieldTag: fieldIdentifier)
                }
            case .ibanFieldTag, .recipientFieldTag, .usageFieldTag:
                if textField.hasText && !textField.isReallyEmpty {
                    applyDefaultStyle(textField)
                    hideErrorLabel(textFieldTag: fieldIdentifier)
                } else {
                    applyErrorStyle(textField)
                    showErrorLabel(textFieldTag: fieldIdentifier)
                }
            }
        }
    }
    
    fileprivate func validateIBANTextField(){
        if let ibanText = ibanField.text, ibanField.hasText {
            if IBANValidator().isValid(iban: ibanText) {
                applyDefaultStyle(ibanField)
                hideErrorLabel(textFieldTag: .ibanFieldTag)
            } else {
                applyErrorStyle(ibanField)
                showValidationErrorLabel(textFieldTag: .ibanFieldTag)
            }
        } else {
            applyErrorStyle(ibanField)
            showErrorLabel(textFieldTag: .ibanFieldTag)
        }
    }
    
    fileprivate func showIBANValidationErrorIfNeeded(){
        if IBANValidator().isValid(iban: lastValidatedIBAN) {
            applyDefaultStyle(ibanField)
            hideErrorLabel(textFieldTag: .ibanFieldTag)
        } else {
            applyErrorStyle(ibanField)
            showValidationErrorLabel(textFieldTag: .ibanFieldTag)
        }
    }

    fileprivate func validateAllInputFields() {
        for textField in paymentInputFields {
            validateTextField(textField)
        }
    }
    
    fileprivate func hideErrorLabels() {
        for errorLabel in paymentInputFieldsErrorLabels {
            errorLabel.isHidden = true
        }
    }
    
    fileprivate func fillInInputFields() {
        recipientField.text = model?.extractions.first(where: {$0.name == "payment_recipient"})?.value
        ibanField.text = model?.extractions.first(where: {$0.name == "iban"})?.value
        usageField.text = model?.extractions.first(where: {$0.name == "payment_purpose"})?.value
        if let amountString = model?.extractions.first(where: {$0.name == "amount_to_pay"})?.value, let amountToPay = Price(extractionString: amountString) {
            self.amountToPay = amountToPay
            let amountToPayText = amountToPay.string
            amountField.text = amountToPayText
        }
        validateAllInputFields()
        disablePayButtonIfNeeded()
    }
    
    fileprivate func disablePayButtonIfNeeded() {
        payButton.isEnabled = paymentInputFields.allSatisfy { !$0.isReallyEmpty } && !paymentProviders.isEmpty && amountToPay.value > 0
    }


    fileprivate func showErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        var errorMessage = ""
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.recipient.non.empty.check",
                                                            comment: " recipient failed non empty check")
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.iban.non.empty.check",
                                                            comment: "iban failed non empty check")
        case .amountFieldTag:
            errorLabel = amountErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.amount.non.empty.check",
                                                            comment: "amount failed non empty check")
        case .usageFieldTag:
            errorLabel = usageErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.purpose.non.empty.check",
                                                            comment: "purpose failed non empty check")
        }
        if errorLabel.isHidden {
            errorLabel.isHidden = false
            errorLabel.textColor = UIColor.from(giniColor: giniHealthConfiguration.paymentInputFieldErrorStyleColor)
            errorLabel.text = errorMessage
        }
    }
    
    fileprivate func showValidationErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        var errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.default.textfield.validation.check",
                                                            comment: "the field failed non empty check")
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginihealth.errors.failed.iban.validation.check",
                                                            comment: "iban failed validation check")
        case .amountFieldTag:
            errorLabel = amountErrorLabel
        case .usageFieldTag:
            errorLabel = usageErrorLabel
        }
        if errorLabel.isHidden {
            errorLabel.isHidden = false
            errorLabel.textColor = UIColor.from(giniColor: giniHealthConfiguration.paymentInputFieldErrorStyleColor)
            errorLabel.text = errorMessage
        }
    }

    fileprivate func hideErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
        case .amountFieldTag:
            errorLabel = amountErrorLabel
        case .usageFieldTag:
            errorLabel = usageErrorLabel
        }
        if !errorLabel.isHidden {
            errorLabel.isHidden = true
        }
        disablePayButtonIfNeeded()
    }
    
    // MARK: - IBAction
    
    @objc func selectBankProviderTapped() {
        var event = TrackingEvent.init(type: PaymentReviewScreenEventType.onBankSelectionButtonClicked)
        if let selectedPaymentProviderName = selectedPaymentProvider?.name {
            event.info = ["paymentProvider" : selectedPaymentProviderName]
        }
        trackingDelegate?.onPaymentReviewScreenEvent(event: event)
        bankProviderButtonView.alpha = 0.5
        UIView.animate(withDuration: 0.5) {
            self.bankProviderButtonView.alpha = 1.0
        }
        presentBankSelectionViewController()
    }
    
    @IBAction func payButtonClicked(_ sender: Any) {
        var event = TrackingEvent.init(type: PaymentReviewScreenEventType.onNextButtonClicked)
        if let selectedPaymentProviderName = selectedPaymentProvider?.name {
            event.info = ["paymentProvider" : selectedPaymentProviderName]
        }
        trackingDelegate?.onPaymentReviewScreenEvent(event: event)
        view.endEditing(true)
        validateAllInputFields()
        validateIBANTextField()
        if let iban = ibanField.text {
            lastValidatedIBAN = iban
        }

        // check if no errors labels are shown
        if (paymentInputFieldsErrorLabels.allSatisfy { $0.isHidden }) {
            
            // check for the 1st run where no provider where selected and saved yet
            if self.selectedPaymentProvider == nil {
                self.selectedPaymentProvider = paymentProviders.first
            }
            if let selectedProvider = selectedPaymentProvider, !amountField.isReallyEmpty
            {
                let amountText = amountToPay.extractionString
                let paymentInfo = PaymentInfo(recipient: recipientField.text ?? "", iban: ibanField.text ?? "", bic: "", amount: amountText, purpose: usageField.text ?? "", paymentProviderScheme: selectedProvider.appSchemeIOS, paymentProviderId: selectedProvider.id)
                model?.createPaymentRequest(paymentInfo: paymentInfo)
                let paymentRecipientExtraction = Extraction(box: nil, candidates: "", entity: "text", value: recipientField.text ?? "", name: "payment_recipient")
                let ibanExtraction = Extraction(box: nil, candidates: "", entity: "iban", value: paymentInfo.iban, name: "iban")
                let referenceExtraction = Extraction(box: nil, candidates: "", entity: "text", value: paymentInfo.purpose, name: "payment_purpose")
                let amoutToPayExtraction = Extraction(box: nil, candidates: "", entity: "amount", value: paymentInfo.amount, name: "amount_to_pay")
                let updatedExtractions = [paymentRecipientExtraction, ibanExtraction, referenceExtraction, amoutToPayExtraction]
                model?.sendFeedback(updatedExtractions: updatedExtractions)
            }
        }
    }
    
    @IBAction func closeButtonClicked(_ sender: UIButton) {
        if (keyboardWillShowCalled) {
            trackingDelegate?.onPaymentReviewScreenEvent(event: TrackingEvent.init(type: .onCloseKeyboardButtonClicked))
            view.endEditing(true)
        } else {
            trackingDelegate?.onPaymentReviewScreenEvent(event: TrackingEvent.init(type: .onCloseButtonClicked))
            dismiss(animated: true, completion: nil)
        }
    }
    
    // MARK: - Keyboard handling
    
    private var keyboardWillShowCalled = false
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            /**
             If keyboard size is not available for some reason, dont do anything
             */
            return
        }
        /**
         Moves the root view up by the distance of keyboard height  taking in account safeAreaInsets.bottom
         */
        if #available(iOS 11.0, *) {
            mainView.bounds.origin.y = keyboardSize.height - view.safeAreaInsets.bottom
        } else {
            mainView.bounds.origin.y = keyboardSize.height
        }
        
        keyboardWillShowCalled = true
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UInt(UIView.AnimationCurve.easeOut.rawValue)
        
        self.keyboardWillShowCalled = false
        
        /**
        Moves back the root view origin to zero. Schedules it on the main dispatch queue to prevent
        the view jumping if another keyboard is shown right after this one is hidden.
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if !self.keyboardWillShowCalled {
                UIView.animate(withDuration: animationDuration, delay: 0.0, options: UIView.AnimationOptions(rawValue: animationCurve), animations: {
                    self.mainView.bounds.origin.y = 0
                }, completion: nil)
            }
        }
    }
    
    func subscribeOnNotifications() {
        subscribeOnKeyboardNotifications()
    }

    func subscribeOnKeyboardNotifications() {
        /**
         Calls the 'keyboardWillShow' function when the view controller receive the notification that a keyboard is going to be shown
         */
        NotificationCenter.default.addObserver(self, selector: #selector(PaymentReviewViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        /**
         Calls the 'keyboardWillHide' function when the view controlelr receive notification that keyboard is going to be hidden
         */
        NotificationCenter.default.addObserver(self, selector: #selector(PaymentReviewViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    fileprivate func unsubscribeFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    fileprivate func unsubscribeFromNotifications() {
        unsubscribeFromKeyboardNotifications()
    }
    
    fileprivate func dismissKeyboardOnTap() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        mainView.addGestureRecognizer(tap)
    }
}

// MARK: - UITextFieldDelegate

extension PaymentReviewViewController: UITextFieldDelegate {
    /**
     Dissmiss the keyboard when return key pressed
     */
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    /**
     Updates amoutToPay, formated string with a currency and removes "0.00" value
     */
    fileprivate func updateAmoutToPayWithCurrencyFormat() {
        if amountField.hasText, let amountFieldText = amountField.text {
            if let priceValue = decimal(from: amountFieldText ) {
                amountToPay.value = priceValue
                if priceValue > 0 {
                    let amountToPayText = amountToPay.string
                    amountField.text = amountToPayText
                } else {
                    amountField.text = ""
                }
            }
        }
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        
        // add currency format when edit is finished
        if TextFieldType(rawValue: textField.tag) == .amountFieldTag {
            updateAmoutToPayWithCurrencyFormat()
        }
        validateTextField(textField)
        if TextFieldType(rawValue: textField.tag) == .ibanFieldTag {
            if textField.text == lastValidatedIBAN {
                showIBANValidationErrorIfNeeded()
            }
        }
        disablePayButtonIfNeeded()
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        applySelectionStyle(textField)
        
        // remove currency symbol and whitespaces for edit mode
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            hideErrorLabel(textFieldTag: fieldIdentifier)
            
            if fieldIdentifier == .amountFieldTag {
                let amountToPayText = amountToPay.stringWithoutSymbol
                amountField.text = amountToPayText
            }
        }
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if TextFieldType(rawValue: textField.tag) == .amountFieldTag,
           let text = textField.text,
           let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            
            // Limit length to 7 digits
            let onlyDigits = String(updatedText
                                        .trimmingCharacters(in: .whitespaces)
                                        .filter { c in c != "," && c != "."}
                                        .prefix(7))
            
            if let decimal = Decimal(string: onlyDigits) {
                let decimalWithFraction = decimal / 100
                
                if let newAmount = Price.stringWithoutSymbol(from: decimalWithFraction)?.trimmingCharacters(in: .whitespaces) {
                    // Save the selected text range to restore the cursor position after replacing the text
                    let selectedRange = textField.selectedTextRange
                    
                    textField.text = newAmount
                    amountToPay.value = decimalWithFraction
                    
                    // Move the cursor position after the inserted character
                    if let selectedRange = selectedRange {
                        let countDelta = newAmount.count - text.count
                        let offset = countDelta == 0 ? 1 : countDelta
                        textField.moveSelectedTextRange(from: selectedRange.start, to: offset)
                    }
                }
            }
            disablePayButtonIfNeeded()
            return false
           }
        return true
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension PaymentReviewViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 1 }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        model?.numberOfCells ?? 1
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "pageCellIdentifier", for: indexPath) as! PageCollectionViewCell
        cell.pageImageView.frame = CGRect(x: 0, y: 0, width: collectionView.frame.width, height: collectionView.frame.height)
        cell.pageImageView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 0.0)
        let cellModel = model?.getCellViewModel(at: indexPath)
        cell.pageImageView.display(image: cellModel?.preview ?? UIImage())
        return cell
    }
    // MARK: - UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = collectionView.frame.height
        let width = collectionView.frame.width
        return CGSize(width: width, height: height)
    }

    // MARK: - For Display the page number in page controll of collection view Cell

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }
    
}

extension PaymentReviewViewController {
    func showError(_ title: String? = nil, message: String) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        let OKAction = UIAlertAction(title: NSLocalizedStringPreferredFormat("ginihealth.alert.ok.title",
                                                                             comment: "ok title for action"), style: .default, handler: nil)
        alertController.addAction(OKAction)
        present(alertController, animated: true, completion: nil)
    }
}
