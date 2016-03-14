import Foundation

class PlansRemote: ServiceRemoteREST {
    typealias SitePlans = (activePlan: Plan, availablePlans: [Plan])
    enum Error: ErrorType {
        case DecodeError
        case UnsupportedPlan
        case NoActivePlan
    }


    func getPlansForSite(siteID: Int, success: SitePlans -> Void, failure: ErrorType -> Void) {
        let endpoint = "sites/\(siteID)/plans"
        let path = pathForEndpoint(endpoint, withVersion: ServiceRemoteRESTApiVersion_1_1)

        api.GET(path,
            parameters: nil,
            success: {
                _, response in
                do {
                    try success(mapPlansResponse(response))
                } catch {
                    failure(error)
                }
            }, failure: {
                _, error in
                failure(error)
        })
    }

}

private func mapPlansResponse(response: AnyObject) throws -> (activePlan: Plan, availablePlans: [Plan]) {
    guard let json = response as? [String: AnyObject] else {
        throw PlansRemote.Error.DecodeError
    }

    let parsedResponse: (Plan?, [Plan]) = try json.reduce((nil, []), combine: {
        (result, item: (key: String, value: AnyObject)) in
        guard let planId = Int(item.key) else {
            throw PlansRemote.Error.DecodeError
        }
        guard let plan = defaultPlans.withID(planId) else {
            throw PlansRemote.Error.UnsupportedPlan
        }
        guard let planDetails = item.value as? [String: AnyObject] else {
            throw PlansRemote.Error.DecodeError
        }
        let plans = result.1 + [plan]
        if let isCurrent = planDetails["current_plan"] as? Bool where
            isCurrent {
            return (plan, plans)
        } else {
            return (result.0, plans)
        }
    })
    guard let activePlan = parsedResponse.0 else {
        throw PlansRemote.Error.NoActivePlan
    }
    let availablePlans = parsedResponse.1.sort()
    return (activePlan, availablePlans)
}

class PlanFeaturesRemote: ServiceRemoteREST {
    
    enum Error: ErrorType {
        case DecodeError
    }
    
    private var cacheDate: NSDate?
    private let cacheFilename = "plan-features.json"
    
    func getPlanFeatures(success: [PlanFeature] -> Void, failure: ErrorType -> Void) {
        if let planFeatures = inMemoryPlanFeatures {
            success(planFeatures)
            return
        }
        
        if let (planFeatures, date) = cachedPlanFeaturesWithDate() {
            inMemoryPlanFeatures = planFeatures
            cacheDate = date
            
            success(planFeatures)
            return
        }
        
        fetchPlanFeatures({ [weak self] planFeatures in
            self?.inMemoryPlanFeatures = planFeatures
            self?.cacheDate = NSDate()
            
            success(planFeatures)
        }, failure: failure)
    }
    
    private var _planFeatures: [PlanFeature]?
    
    private var inMemoryPlanFeatures: [PlanFeature]? {
        get {
            // If we have something in memory and it's less than a day old, return it.
            if let planFeatures = _planFeatures,
                let cacheDate = cacheDate where
                NSCalendar.currentCalendar().isDateInToday(cacheDate) {
                    return planFeatures
            }
            
            return nil
        }
        
        set {
            _planFeatures = newValue
        }
    }
    
    private func cachedPlanFeatures() -> [PlanFeature]? {
        guard let (planFeatures, _) = cachedPlanFeaturesWithDate() else { return nil}

        return planFeatures
    }
    
    private func cachedPlanFeaturesWithDate() -> ([PlanFeature], NSDate)? {
        if let cacheFileURL = cacheFileURL,
            let path = cacheFileURL.path {
                
            if NSFileManager.defaultManager().fileExistsAtPath(path) {
                do {
                    let attributes = try NSFileManager.defaultManager().attributesOfItemAtPath(path)
                    if let modificationDate = attributes[NSFileModificationDate] as? NSDate {
                        if NSCalendar.currentCalendar().isDateInToday(modificationDate) {
                            let response = try NSString(contentsOfURL: cacheFileURL, encoding: NSUTF8StringEncoding)
                            return (try mapPlanFeaturesResponse(response), modificationDate)
                        }
                    }
                }
                catch {}
            }
        }
        
        return nil
    }
    
    private func fetchPlanFeatures(success: [PlanFeature] -> Void, failure: ErrorType -> Void) {
        let endpoint = "plans/features"
        let path = pathForEndpoint(endpoint, withVersion: ServiceRemoteRESTApiVersion_1_2)
        
        api.GET(path,
            parameters: nil,
            success: {
                [weak self] requestOperation, response in
                self?.cacheResponseData(requestOperation.responseData)
                do {
                    try success(mapPlanFeaturesResponse(response))
                } catch {
                    failure(error)
                }
            }, failure: {
                _, error in
                failure(error)
        })
    }
    
    private var cacheFileURL: NSURL? {
        guard let cacheDirectory = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first else { return nil }
        
        return cacheDirectory.URLByAppendingPathComponent(cacheFilename)
    }
    
    private func cacheResponseData(responseData: NSData?) {
        guard let responseData = responseData else { return }
        guard let cacheFileURL = cacheFileURL else { return }
        
        responseData.writeToURL(cacheFileURL, atomically: true)
    }
}

private func mapPlanFeaturesResponse(response: AnyObject) throws -> [PlanFeature] {
    // TODO: Parse response!
    return [PlanFeature(slug: "custom-design", title: "Custom Design", description: "Lorem ipsum", iconName: "")]
}
