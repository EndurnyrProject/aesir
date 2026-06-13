defmodule Aesir.Commons.InterServer.Schemas.Session do
  @moduledoc """
  Player session value carried across the cluster during the login handoff
  (account -> char -> zone). Stored as a Horde.Registry value; not persisted.
  """
  use TypedStruct

  @type state :: :authenticating | :char_select | :in_game | :disconnected
  @type server :: :account_server | :char_server | :zone_server

  typedstruct do
    field :account_id, non_neg_integer(), enforce: true
    field :login_id1, non_neg_integer()
    field :login_id2, non_neg_integer()
    field :auth_code, non_neg_integer()
    field :username, String.t()
    field :state, state()
    field :current_server, server()
    field :current_char_id, non_neg_integer() | nil
    field :node, node()
    field :created_at, DateTime.t()
    field :last_activity, DateTime.t()
  end

  @spec new(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: t()
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
      node: Node.self(),
      created_at: now,
      last_activity: now
    }
  end

  @spec update_activity(t()) :: t()
  def update_activity(session), do: %{session | last_activity: DateTime.utc_now()}

  @spec transition_to_char_server(t()) :: t()
  def transition_to_char_server(session),
    do: update_activity(%{session | state: :char_select, current_server: :char_server})

  @spec transition_to_game(t(), non_neg_integer()) :: t()
  def transition_to_game(session, char_id),
    do:
      update_activity(%{
        session
        | state: :in_game,
          current_server: :zone_server,
          current_char_id: char_id
      })

  @spec disconnect(t()) :: t()
  def disconnect(session), do: update_activity(%{session | state: :disconnected})
end
