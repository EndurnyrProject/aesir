defmodule Aesir.ZoneServer.Mmo.Skill.Menu do
  @moduledoc """
  Capability behaviour for skills whose cast opens a `SkillMenu` and acts on the
  reply (SA_AUTOSPELL's bolt list, SA_CREATECON's converter list).

  A skill opts in by declaring `@behaviour Skill.Menu` and implementing
  `on_menu_reply/3`. It may additionally implement `on_menu_reply/4` when it
  needs session-owned context. Its `cast/4` stages the offer on `PlayerState`'s
  `:pending_menu_offer`; the session handler sends it and parks it. When the
  client answers, `SkillMenuHandler` validates the reply against the parked offer
  and routes the accepted selection back here through
  `Skill.Catalog.menu_module_for/1`.

  The two halves are deliberately split: a cast only ever sees `PlayerState` and
  cannot reach the connection, and the pending menu is session state, not player
  state (it is not persisted and dies with the session).
  """
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Acts on the selection the client made from this skill's menu.

  `selection.id` is already validated as one of the offered ids, and
  `selection.extras` carries any additional item ids chosen by the client.
  `level` is the level of the cast that opened the menu. A cancel never reaches
  here.
  """
  @callback on_menu_reply(
              PlayerState.t(),
              %{id: non_neg_integer(), extras: [non_neg_integer()]},
              pos_integer()
            ) :: {:ok, PlayerState.t()} | {:error, atom()}

  @doc """
  Acts on a validated selection with minimal session-owned context.

  Modules implementing this optional callback receive `%{homunculus: state}`.
  """
  @callback on_menu_reply(
              PlayerState.t(),
              %{id: non_neg_integer(), extras: [non_neg_integer()]},
              pos_integer(),
              %{required(:homunculus) => struct() | nil}
            ) :: {:ok, PlayerState.t()} | {:error, atom()}

  @optional_callbacks on_menu_reply: 4
end
