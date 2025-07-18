defmodule Aesir.Commons.InterServer.Schemas.Session do
  @moduledoc """
  Memento schema for managing player sessions across the cluster.
  Stores authentication data and current server state.
  """
  use Memento.Table,
    attributes: [
      :account_id,
      :login_id1,
      :login_id2,
      :auth_code,
      :username,
      :state,
      :current_server,
      :current_char_id,
      :created_at,
      :last_activity
    ],
    index: [:username, :current_server],
    type: :set

  @type t :: %__MODULE__{
          account_id: non_neg_integer(),
          login_id1: non_neg_integer(),
          login_id2: non_neg_integer(),
          auth_code: non_neg_integer(),
          username: String.t(),
          state: :authenticating | :char_select | :in_game | :disconnected,
          current_server: :account_server | :char_server | :zone_server,
          current_char_id: non_neg_integer() | nil,
          created_at: DateTime.t(),
          last_activity: DateTime.t()
        }

  def new(account_id, login_id1, login_id2, auth_code, username) do
    now = DateTime.utc_now()

    %__MODULE__{
      account_id: account_id,
      login_id1: login_id1,
      login_id2: login_id2,
      auth_code: auth_code,
      username: username,
      state: :authenticating,
      current_server: :account_server,
      current_char_id: nil,
      created_at: now,
      last_activity: now
    }
  end

  def update_activity(session) do
    %{session | last_activity: DateTime.utc_now()}
  end

  def transition_to_char_server(session) do
    update_activity(%{session | state: :char_select, current_server: :char_server})
  end

  def transition_to_game(session, char_id) do
    update_activity(%{
      session
      | state: :in_game,
        current_server: :zone_server,
        current_char_id: char_id
    })
  end

  def disconnect(session) do
    update_activity(%{session | state: :disconnected})
  end
end
