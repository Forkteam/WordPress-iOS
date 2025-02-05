class ActivityLogTestData {

    let contextManager = TestContextManager()

    let testPostID = 441
    let testSiteID = 137726971

    let pingbackText = "Pingback to Camino a Machu Picchu from Tren de Machu Picchu a Cusco – eToledo"
    let postText = "Tren de Machu Picchu a Cusco"
    let commentText = "Comment by levitoledo on Hola Lima! 🇵🇪: Great post! True talent!"
    let themeText = "Spatial"
    let settingsText = "Default post category changed from \"subcategory\" to \"viajes\""
    let siteText = "Atomic"
    let pluginText = "WP Job Manager 1.31.1"

    let testPluginSlug = "wp-job-manager"
    let testSiteSlug = "etoledomatomicsite01.blog"

    var testPostUrl: String {
        return "https://wordpress.com/read/blogs/\(testSiteID)/posts/\(testPostID)"
    }
    var testPluginUrl: String {
        return "https://wordpress.com/plugins/\(testPluginSlug)/\(testSiteSlug)"
    }

    var testCommentURL: String {
        return "https://wordpress.com/comment/137726971/7"
    }

    func getCommentEventDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-comment.json")
    }

    func getPostEventDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-post.json")
    }

    func getPingbackDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-pingback-content.json")
    }

    func getPostContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-post-content.json")
    }

    func getCommentContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-comment-content.json")
    }

    func getThemeContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-theme-content.json")
    }

    func getSettingsContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-settings-content.json")
    }

    func getSiteContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-site-content.json")
    }

    func getPluginContentDictionary() throws -> JSONObject {
        return try .loadFile(named: "activity-log-plugin-content.json")
    }

    func getCommentRangeDictionary() throws -> JSONObject {
        let dictionary = try getCommentContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    func getPostRangeDictionary() throws -> JSONObject {
        let dictionary = try getPostContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    func getThemeRangeDictionary() throws -> JSONObject {
        let dictionary = try getThemeContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    func getItalicRangeDictionary() throws -> JSONObject {
        let dictionary = try getSettingsContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    func getSiteRangeDictionary() throws -> JSONObject {
        let dictionary = try getSiteContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    func getPluginRangeDictionary() throws -> JSONObject {
        let dictionary = try getPluginContentDictionary()
        return getRange(at: 0, from: dictionary)
    }

    private func getRange(at index: Int, from dictionary: [String: AnyObject]) -> [String: AnyObject] {
        let ranges = getRanges(from: dictionary)
        return ranges[index]
    }

    private func getRanges(from dictionary: [String: AnyObject]) -> [[String: AnyObject]] {
        return dictionary["ranges"] as! [[String: AnyObject]]
    }
}
