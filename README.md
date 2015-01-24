GOODDATA MARKETO CONNECTOR
==========================
Marketo SOAP/REST services to GoodData ADS

## Overview
With the Marketo Connector a complete transfer of all available lead data is automatically moved *and* kept in sync with GoodData ADS. Supporting both the Marketo REST & SOAP the GoodData Marketo Connector adapts to the source data making installation as simple as entering your login information.

### Marketo
The central concept of the Marketo API is a "Lead". Each lead contains default attributes like City or Email in addition to custom attributes added by the client. The Marketo Connector downloads and synchronizes all leads and lead changes for a given Marketo client. The connector utitlizes two main calls, *get_lead_changes* and *get_multiple_leads*, these feed into the ADS tables *marketo_changes* and *marketo_leads* respectively. For examples, take a look at the code within the *examples* directory.

### Getting Started

1. Install jruby `rvm install jruby` and then `rvm use jruby` (tested on jruby 1.7.16.1)
2. [Install DSS for Ruby](https://confluence.intgdc.com/pages/viewpage.action?title=DSS+Alpha+Version+-+User+Guide&spaceKey=plat)
3. Clone this repository.
4. Configure authentication in bin/auth.json.
5. Zip the the entire "bin" folder to a new zip file.
6. Upload the zip file it as a Ruby process, schedule it to run daily, every 12 hours.

### Configuration & Keys
To use the Marketo Connector you must have credentials for the following services.

- [Marketo REST API](http://developers.marketo.com/blog/quick-start-guide-for-marketo-rest-api/).
- [Marketo SOAP API](http://developers.marketo.com/documentation/soap/).
- [GoodData Username, Password, & Project ID](https://na1.secure.gooddata.com/account.html?clicked_trial_link=1#/registration/projectTemplate/urn%3Agooddata%3AOnboarding).
- [AWS S3](http://aws.amazon.com/s3/).

#### File Tree

    ├── bin
    │   ├── Gemfile
    │   ├── auth.json
    │   ├── main.rb
    │   └── process.rbx
    │
    ├── examples
    │   ├── all_lead_changes.rb
    │   ├── all_leads.rb
    │   └── lead_changes_to_ads.rb
    │
    ├── lib
    │   ├── gooddata_marketo
    │   │   ├── adapters
    │   │   │   └── rest.rb
    │   │   ├── client.rb
    │   │   ├── data
    │   │   │   ├── activity_types.rb
    │   │   │   └── reserved_sql_keywords.rb
    │   │   ├── helpers
    │   │   │   ├── s3.rb
    │   │   │   ├── stringwizard.rb
    │   │   │   ├── table.rb
    │   │   │   └── webdav.rb
    │   │   ├── loads.rb
    │   │   └── models
    │   │       ├── campaigns.rb
    │   │       ├── channels.rb
    │   │       ├── child
    │   │       │   ├── activity.rb
    │   │       │   ├── criteria.rb
    │   │       │   ├── lead.rb
    │   │       │   └── mobj.rb
    │   │       ├── etl.rb
    │   │       ├── leads.rb
    │   │       ├── load.rb
    │   │       ├── mobjects.rb
    │   │       ├── streams.rb
    │   │       ├── tags.rb
    │   │       └── validate.rb
    │   └── gooddata_marketo.rb
    │
    └── tests
        └── test.rb

## Custom Scripts
In addition to running the main process you can also write scripts for exploration and small transformations with the Marketo API. To start, require the Marketo Connector and create a client.

    require 'marketo_connector'

    user = ""
    key = ""
    subdomain = ""

    client = GoodDataMarketo.connect(:user_id => user,
                                      :encryption_key => key,
                                      :api_subdomain => subdomain)

From the client you can get a specific lead or a stream of ids.

    lead = client.leads.get_by_email('email@email.com')
    leads = client.leads.get_multiple ['23590','2930','9209'], :filters => 'Merge Leads', :type => 'IDNUM'

## Customizing Calls
Marketo API queries can be very time consuming, in the hours or days range, before a response returns. This is why the Marketo API allows for very complex filtration options like creation date, data-type, request size etc. Filtering your queries by some level is **required** due to the size and slower speed of Marketo. Keep in mind, as of this post RUBY Processes on the GoodData platform automatically terminate after 5 hours. Setting up configuration options for the two main calls, `client.leads.get_changes` and `client.leads.get_multiple` is almost identical, you can learn more about them [here](http://developers.marketo.com/documentation/soap/getmultipleleads/).

#### Important Configurations

* ` :timeout => Int `

Specifies the amount of time before you want a call to the API to fail. Currently the library wide default is 120 which is also the the time allocated to the SAVON GEM in the initialization of the client. To go past that you will need to change the timeout when the client is first initialized.

* ` :filters => Array `

A list of activity types which are translated into the *activity_name_filters*. Due to changes in the Marketo API becareful to print these in complete form like 'Merge Leads' instead of 'MergeLeads' or 'Webpage Clicks' instead of 'webpageClicks'.

* ` :type => String `

Defines the type of your query. For instance, `:type => 'IDNUM'` would mean you are searching for data using a Marketo ID, or you might use `:type => 'EMAIL'` if you are querying using an email. In specific cases like `client.leads.get_by_id` the type is set for you.

If the given call you are looking for is not fully implemented, you can always build the complete soap request your self by calling `client.call` directly.
Outside of the authentication options, the default configuration for the client is in *marketo_connector/client.rb* under the parameter *DEFAULT_CONFIG*.

## Leads
All calls to Marketo return objects that contain attributes. Currently the Marketo Connector supports *Lead* and *Activity* where Activity is a child of lead containing the ID and values pertaining to the lead's activity. Custom attributes can be added to leads which include values, accessing them looks like this:

    leads = client.leads.get_changes :last_created_at => '12/02/2013'
    lead = leads.first
    custom_form = lead.attributes['c__Custom_Form']

Where `custom_form` will now contain the given value of the lead. Lead and Activity objects can also be flattened to save to CSV for parsing in the future.

    lead = client.leads.get_by_email('john@smith.com')

    CSV.open('leads.csv', 'wb') do |csv|

      csv << lead.headers # => Incase you wanted to wanted the headers of attributes also saved to CSV.
      csv << lead.to_row

    end

You can also extract the activities of a given lead through `lead.activities` or changes of a given lead with `lead.changes`. For example if you wanted to write the attributes for leads which included the City 'San Francisco' to csv...

    leads = client.leads.get_changes :filters => ['Email Opens', 'Merge Leads'], :lastest_created_at => '10/11/2014'

    san_francisco_leads = leads.select {|lead| lead.attributes['City'] == 'San Francisco'}

    CSV.open('leads.csv', 'wb') do |csv|
      san_francisco_leads.each do |lead|
        csv << lead.to_row
      end
    end

In addition, you can always work with the raw response of the lead object with `lead.raw`.

## Streams
Specific to getMultipleLeads, getLeadChanges, getMObjects, and getLeadActivity calls, the Marketo SOAP API supports "Streams" which allow you to increment through large responses by offset stamp or stream ID (just like pagenate).
Within the client script (*lib/marketo_connector/client.rb*) are two calls, a streaming function which automatically works through APIs, building a complete object.

In the event the Marketo times out **AND** you gave specific date configurations like *:started_at => TIME* or *:oldest_created_at => TIME*, the stream will increment your calls into smaller time windows until it does receive a response within the given timeout configuration. This is helpful to insure that the most relevant data is always in a clients account. You can also deactivate this by passing the configuration symbol *:safe* and setting it to **false**.

## Custom Objects
Marketo allows you to query the API using what it calls *criteria* which is a hash comprised of the attribute name and value with a comparison statement like *EQ* "Equals" or *LT* "Less Then". Many criteria hashes can be sent with a given request, due to the size of these queries it is also suggest that you do so but rather than forcing you to do with large arrays of criteria hashes you simply add criteria to the given *client.mobject* like so:

    criteria_one = {
        :attr_name => "Id", # See the types of content it can search above.
        :comparison => "LE",
        :attr_value => "1010"
    }

    >> client.mobjects.add(criteria_one)
    [{:attr_name => 'Id', :comparison => 'LE', :attr_value => '1010'}]

    criteria_two = {
        :attr_name => "Zip", # See the types of content it can search above.
        :comparison => "EQ",
        :attr_value => "94104"
    }

    >> client.mobjects.add(criteria_two)
    [{:attr_name => 'Id', :comparison => 'LE', :attr_value => '1010'}, {:attr_name => 'Zip', :comparison => 'EQ', :attr_value => '94104'}]

The data is stored in a class array which allows you to do this:

    objects = client.mobjects.get

You can also make requests with one criteria hash like this:

    client.mobjects.get :criteria => HASH

Finally criteria can be removed by name with: ` client.mbobjects.remove_criteria 'NAME' `.

## Supported Calls

* [` client.leads.get_changes `](http://developers.marketo.com/documentation/soap/getleadchanges/) - Optional config. Streaming is required.

* [` client.leads.get_multiple `](http://developers.marketo.com/documentation/soap/getmultipleleads/) - Requires an query Array, optional Config.

* [` client.leads.get_lead `](http://developers.marketo.com/documentation/soap/getlead/) - Requires query String, optional config.

* [` client.mobjects `](http://developers.marketo.com/documentation/soap/getcustomobjects/) - Requires criteria to be set (See Custom Objects above)

* [` client.usage `](http://developers.marketo.com/documentation/rest/get-daily-usage/) -  Requires API key to within REST config.

* [` client.channels `](http://developers.marketo.com/documentation/soap/getchannels/) - Requires query value, optional config.

* [` client.tags `](http://developers.marketo.com/documentation/soap/gettags/) - Requires the Lead email or ID for the query, optional config.

## Custom Requests
You can call custom requests should you need want more specific control or use of a feature.

#### Direct Call
A single call is ` client.call(WEB_METHOD, MESSAGE) ` where WEB_METHOD is the specific SOAP function you are attempting to use and message is the SOAP request message (as a hash).

#### Streaming Calls
In addition for web methods that support streaming, you can using `client.stream(WEB_METHOD, MESSAGE)` to automatically iterate through either *offset* or *start_position* and return an array of results in the correct type.


