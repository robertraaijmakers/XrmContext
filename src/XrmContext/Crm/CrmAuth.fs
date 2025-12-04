module DG.XrmContext.CrmAuth

open System
open System.Net
open Microsoft.Xrm.Sdk
open Microsoft.Xrm.Sdk.Client

// Get credentials based on provider, username, password and domain
let internal getCredentials provider username password domain =

  let (password_:string) = password
  let ac = AuthenticationCredentials()

  match provider with
  | AuthenticationProviderType.ActiveDirectory ->
      ac.ClientCredentials.Windows.ClientCredential <-
        new NetworkCredential(username, password_, domain)

  | AuthenticationProviderType.OnlineFederation -> // CRM Online using Office 365 
      ac.ClientCredentials.UserName.UserName <- username
      ac.ClientCredentials.UserName.Password <- password_

  | AuthenticationProviderType.Federation -> // Local Federation
      ac.ClientCredentials.UserName.UserName <- username
      ac.ClientCredentials.UserName.Password <- password_

  | _ -> failwith "No valid authentification provider was used."

  ac

// Get Organization Service Proxy
let internal getOrganizationServiceProxy
  (serviceManagement:IServiceManagement<IOrganizationService>)
  (authCredentials:AuthenticationCredentials) =
  let ac = authCredentials

  match serviceManagement.AuthenticationType with
  | AuthenticationProviderType.ActiveDirectory ->
      new OrganizationServiceProxy(serviceManagement, ac.ClientCredentials) :> IOrganizationService
  | _ ->
      new OrganizationServiceProxy(serviceManagement, ac.SecurityTokenResponse) :> IOrganizationService

// Get Organization Service Proxy using MFA
let ensureClientIsReady (client: Microsoft.PowerPlatform.Dataverse.Client.ServiceClient) =
  match client.IsReady with
  | false ->
    let s = sprintf "Client could not authenticate. If the application user was just created, it might take a while before it is available.\n%s" client.LastError 
    in failwith s
  | true -> client

let internal getCrmServiceClient userName password (orgUrl:Uri) mfaAppId mfaReturnUrl =
  // Modern .NET 8 approach using ServiceClient
  // Support interactive OAuth with browser-based login
  let connectionString = 
    match String.IsNullOrEmpty(password) with
    | true -> 
        // Interactive OAuth - opens browser for login (like your other project)
        sprintf "AuthType=OAuth;Url=%s;Username=%s;AppId=%s;RedirectUri=%s;LoginPrompt=Auto" 
          (orgUrl.ToString()) userName mfaAppId mfaReturnUrl
    | false ->
        // Username/Password OAuth (original behavior)
        sprintf "AuthType=OAuth;Url=%s;Username=%s;Password=%s;AppId=%s;RedirectUri=%s;LoginPrompt=Never" 
          (orgUrl.ToString()) userName password mfaAppId mfaReturnUrl
  
  new Microsoft.PowerPlatform.Dataverse.Client.ServiceClient(connectionString)
  |> ensureClientIsReady
  |> fun x -> x :> IOrganizationService

let internal getCrmServiceClientClientSecret (org: Uri) appId clientSecret =
  let connectionString = sprintf "AuthType=ClientSecret;Url=%s;ClientId=%s;ClientSecret=%s" (org.ToString()) appId clientSecret
  new Microsoft.PowerPlatform.Dataverse.Client.ServiceClient(connectionString)
  |> ensureClientIsReady
  |> fun x -> x :> IOrganizationService

let internal getCrmServiceClientConnectionString (connectionString: string option) =
  if connectionString.IsNone then failwith "Ensure connectionString is set when using ConnectionString method" else
  new Microsoft.PowerPlatform.Dataverse.Client.ServiceClient(connectionString.Value)
  |> ensureClientIsReady
  |> fun x -> x :> IOrganizationService


// Authentication
let internal getServiceManagement org = 
    ServiceConfigurationFactory.CreateManagement<IOrganizationService>(org)

let internal authenticate (serviceManagement:IServiceManagement<IOrganizationService>) ap username password domain =
    serviceManagement.Authenticate(getCredentials ap username password domain)
  
