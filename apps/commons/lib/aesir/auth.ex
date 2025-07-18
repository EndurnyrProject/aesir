defmodule Aesir.Auth do
  @moduledoc """
  Authentication context for user login and account management.
  """

  import Ecto.Query, warn: false
  alias Aesir.Models.Account
  alias Aesir.Repo

  @doc """
  Authenticates a user with userid and password.

  Returns {:ok, account} on successful authentication or 
  {:error, reason} on failure.
  """
  def authenticate_user(userid, password) when is_binary(userid) and is_binary(password) do
    case get_account_by_userid(userid) do
      nil ->
        # Run bcrypt to prevent timing attacks even when user doesn't exist
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      account ->
        if verify_password(password, account.user_pass) and account_active?(account) do
          {:ok, update_login_info(account)}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc """
  Gets an account by userid.
  """
  def get_account_by_userid(userid) do
    Repo.get_by(Account, userid: userid)
  end

  @doc """
  Gets an account by id.
  """
  def get_account!(id), do: Repo.get!(Account, id)

  @doc """
  Creates a new account.
  """
  def create_account(attrs \\ %{}) do
    attrs =
      Map.put(attrs, :user_pass, hash_password(attrs[:user_pass] || attrs["user_pass"]))

    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an account.
  """
  def update_account(%Account{} = account, attrs) do
    attrs =
      if attrs[:user_pass] || attrs["user_pass"] do
        Map.put(attrs, :user_pass, hash_password(attrs[:user_pass] || attrs["user_pass"]))
      else
        attrs
      end

    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an account.
  """
  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  @doc """
  Hashes a password using bcrypt.
  """
  def hash_password(password) when is_binary(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @doc """
  Verifies a password against a hash.
  """
  def verify_password(password, hash) when is_binary(password) and is_binary(hash) do
    Bcrypt.verify_pass(password, hash)
  end

  @doc """
  Checks if an account is active (not banned or expired).
  """
  def account_active?(%Account{} = account) do
    now = NaiveDateTime.utc_now()

    # Check if account is banned (state 5 = banned)
    banned = account.state == 5

    # Check if account is temporarily banned
    temp_banned = account.unban_time && NaiveDateTime.compare(now, account.unban_time) == :lt

    # Check if account is expired
    expired =
      account.expiration_time && NaiveDateTime.compare(now, account.expiration_time) == :gt

    not (banned or temp_banned or expired)
  end

  @doc """
  Updates login information for an account.
  """
  def update_login_info(%Account{} = account) do
    now = NaiveDateTime.utc_now()

    {:ok, updated_account} =
      account
      |> Account.changeset(%{
        logincount: account.logincount + 1,
        lastlogin: now
      })
      |> Repo.update()

    updated_account
  end

  @doc """
  Gets account state description for debugging.
  """
  def get_account_state_description(state) do
    case state do
      0 -> "Normal"
      1 -> "Unregistered ID"
      2 -> "Incorrect Password"
      3 -> "This ID is expired"
      4 -> "Rejected from Server"
      5 -> "Blocked by the GM Team"
      6 -> "Your Game's EXE file is not the latest version"
      7 -> "Banned until"
      8 -> "Server is over populated"
      9 -> "No more accounts may be connected from this company"
      10 -> "MSI_REFUSE_BAN_BY_DBA"
      11 -> "MSI_REFUSE_EMAIL_NOT_CONFIRMED"
      12 -> "MSI_REFUSE_BAN_BY_GM"
      13 -> "MSI_REFUSE_TEMP_BAN_FOR_DBWORK"
      14 -> "MSI_REFUSE_SELF_LOCK"
      15 -> "MSI_REFUSE_NOT_PERMITTED_GROUP"
      99 -> "This ID has been totally erased"
      _ -> "Unknown state"
    end
  end
end
