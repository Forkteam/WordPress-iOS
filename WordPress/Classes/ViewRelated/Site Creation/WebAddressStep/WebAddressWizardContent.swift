import UIKit

final class WebAddressWizardContent: UIViewController {
    private let service: SiteAddressService
    private var dataCoordinator: (UITableViewDataSource & UITableViewDelegate)?
    private let selection: (SiteAddress) -> Void

    @IBOutlet weak var table: UITableView!

    private let throttle = Scheduler(seconds: 1)

    private lazy var headerData: SiteCreationHeaderData = {
        let title = NSLocalizedString("Choose a domain name for your site", comment: "Create site, step 4. Select domain name. Title")
        let subtitle = NSLocalizedString("This is where people will find you on the internet", comment: "Create site, step 4. Select domain name. Subtitle")
        return SiteCreationHeaderData(title: title, subtitle: subtitle)
    }()

    init(service: SiteAddressService, selection: @escaping (SiteAddress) -> Void) {
        self.service = service
        self.selection = selection
        super.init(nibName: String(describing: type(of: self)), bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyTitle()
        setupBackground()
        setupTable()
    }

    private func applyTitle() {
        title = NSLocalizedString("3 of 3", comment: "Site creation. Step 3. Screen title")
    }

    private func setupBackground() {
        view.backgroundColor = WPStyleGuide.greyLighten30()
    }

    private func setupTable() {
        setupTableBackground()
        setupCell()
        setupHeader()
        hideSeparators()
    }

    private func setupTableBackground() {
        table.backgroundColor = WPStyleGuide.greyLighten30()
    }

    private func hideSeparators() {
        table.tableFooterView = UIView(frame: .zero)
    }

    private func setupCell() {
        let cellName = AddressCell.cellReuseIdentifier()
        let nib = UINib(nibName: cellName, bundle: nil)
        table.register(nib, forCellReuseIdentifier: cellName)
    }

    private func setupHeader() {
        let header = TitleSubtitleTextfieldHeader(frame: .zero)
        header.setTitle(headerData.title)
        header.setSubtitle(headerData.subtitle)

        header.textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        table.tableHeaderView = header

        // This is the only way I found to insert a stack view into the header without breaking the autolayout constraints. We do something similar in Reader
        header.centerXAnchor.constraint(equalTo: table.centerXAnchor).isActive = true
        header.widthAnchor.constraint(equalTo: table.layoutMarginsGuide.widthAnchor).isActive = true
        header.topAnchor.constraint(equalTo: table.layoutMarginsGuide.topAnchor).isActive = true

        table.tableHeaderView?.layoutIfNeeded()
        table.tableHeaderView = table.tableHeaderView
    }

    @objc
    private func textChanged(sender: UITextField) {
        guard let searchTerm = sender.text, searchTerm.isEmpty == false else {
            return
        }

        throttle.throttle { [weak self] in
            self?.fetchAddresses(searchTerm)
        }
    }

    private func fetchAddresses(_ searchTerm: String) {
        service.addresses(for: Locale.current) { [weak self] results in
            switch results {
            case .error(let error):
                self?.handleError(error)
            case .success(let data):
                self?.handleData(data)
            }
        }
    }

    private func handleError(_ error: Error) {
        debugPrint("=== handling error===")
    }

    private func handleData(_ data: [SiteAddress]) {
        dataCoordinator = TableDataCoordinator(data: data, cellType: AddressCell.self, selection: didSelect)
        table.dataSource = dataCoordinator
        table.delegate = dataCoordinator
        table.reloadData()
    }

    private func didSelect(_ segment: SiteAddress) {
        selection(segment)
    }
}
