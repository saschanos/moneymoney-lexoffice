WebBanking{
    version = 1.0,
    url = "https://api.lexoffice.io",
    description = "lexoffice",
    services = {"lexoffice Account"}
}

local apiKey

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "lexoffice Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  apiKey = password
end

function ListAccounts (knownAccounts)
  -- Return array of accounts.
  local account = {
    name = "lexoffice Account",
    owner = "Jane Doe",
    accountNumber = "111222333444",
    bankCode = "80007777",
    currency = "EUR",
    type = "AccountTypeOther"
  }
  return {account}
end

function RefreshAccount (account, since)
    -- TODO: lexoffice lists cashwire transaction done by lexoffice as "paid" although they are not booked by the bank (ticket created)
    local path = "/v1/voucherlist?voucherType=purchaseinvoice,salesinvoice&voucherStatus=open&size=250";
    local postData = {}
    local headers = {}

    headers["Authorization"] = "Bearer " .. apiKey
    headers["Accept"] = "application/json"

    connection = Connection()
    content = connection:request("GET", url .. path, httpBuildQuery(postData), nil, headers)

    json = JSON(content)
    rows = json:dictionary()["content"]

    local transactions = {}
    local balance = 0

    for i, row in ipairs(rows) do
        local transaction = {}
        local amount

        if row.voucherType == "salesinvoice" then
            amount = row.totalAmount
        else
            amount = row.totalAmount * -1;
        end

        transaction.bookingDate = parseDate(row.voucherDate)
        transaction.name = row.contactName
        transaction.currency = "EUR"
        transaction.amount = amount
        transaction.purpose = row.voucherNumber
        transaction.booked = false -- otherwise it would not be possible to remove them

        table.insert(transactions, transaction)
        balance = balance + amount
    end

    return {balance=balance, transactions=transactions}
end

function EndSession ()
  -- Logout.
end

function httpBuildQuery(params)
    local str = ''
    for key, value in pairs(params) do
        str = str .. key .. "=" .. value .. "&"
    end
    return str.sub(str, 1, -2)
end

-- https://gist.github.com/zwh8800/9b0442efadc97408ffff248bc8573064
function parseDate(date)
    local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
    local year, month, day, hour, minute,
    seconds, offsetsign, offsethour, offsetmin = date:match(pattern)
    local timestamp = os.time{year = year, month = month,
                              day = day, hour = hour, min = minute, sec = seconds}
    local offset = 0
    if offsetsign ~= 'Z' then
        offset = tonumber(offsethour) * 60 + tonumber(offsetmin)
        if xoffset == "-" then offset = offset * -1 end
    end

    return timestamp + offset
end