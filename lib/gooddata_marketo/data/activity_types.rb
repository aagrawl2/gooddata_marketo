
class ActivityTypes

    attr_accessor :edited
    attr_accessor :values

  def initialize
    @values = [
        "Activity Pruning",
        "Add to List",
        "Add to Nurture",
        "Add to Opportunity",
        "Add to Segment",
        "Add to SFDC Campaign",
        "Add to Smart Campaign",
        "Assign Nurture Content",
        "Attend Event",
        "Capture Activity History",
        "Capture Campaign Membership History",
        "Capture List Membership History",
        "Change Account Owner",
        "Change Attribute Datatype",
        "Change CRM User",
        "Change Custom Object",
        "Change Data Value",
        "Change Nurture Cadence",
        "Change Nurture Exhausted",
        "Change Nurture Track",
        "Change Owner",
        "Change Program Data",
        "Change Revenue Stage",
        "Change Revenue Stage Manually",
        "Change Score",
        "Change Segment",
        "Change Status in Progression",
        "Change Status in SFDC Campaign",
        "Click Email",
        "Click Link",
        "Click Sales Email",
        "Click Shared Link",
        "Compute Data Value",
        "Convert Lead",
        "Create Task",
        "Decide Test Group Winner",
        "Delete Lead from SFDC",
        "Email Bounced",
        "Email Bounced Soft",
        "Email Delivered",
        "Enrich with Data.com",
        "Field Reparent",
        "Fill Out Form",
        "Interesting Moment",
        "Lead Assigned",
        "Lead Pruning",
        "Merge Attributes",
        "Merge Leads",
        "New Lead",
        "New SFDC Opportunity",
        "Nurture Deploy",
        "Open Email",
        "Open Sales Email",
        "Receive Sales Email",
        "Received Forward to Friend Email",
        "Register for Event",
        "Remove from Flow",
        "Remove from List",
        "Remove from Opportunity",
        "Remove from SFDC Campaign",
        "Request Campaign",
        "Resolve Conflicts",
        "Resolve Ruleset",
        "Revenue Stage Initial Assignment",
        "Reward Test Group Variant",
        "Run Sub-flow",
        "Sales Email Bounced",
        "Schedule Test Variants",
        "Segmentation Approval",
        "Send Alert",
        "Send Email",
        "Send Sales Email",
        "Sent Forward to Friend Email",
        "SFDC Activity",
        "SFDC Activity Updated",
        "SFDC Merge Leads",
        "Share Content",
        "Sync Lead to SFDC",
        "Sync Lead Updates to SFDC",
        "Touch Complete",
        "Unsubscribe Email",
        "Update Opportunity",
        "Visit Webpage",
        "Wait"
    ]
  end

  def set_types array_types
      self.edited = true
      self.values = array_types
  end

end



