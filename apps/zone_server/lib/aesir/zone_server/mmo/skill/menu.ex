defmodule Aesir.ZoneServer.Mmo.Skill.Menu do
  @moduledoc """
  Capability behaviour for skills whose cast opens a `SkillMenu` and acts on the
  reply (SA_AUTOSPELL's bolt list, SA_CREATECON's converter list).

  A skill opts in by declaring `@behaviour Skill.Menu` and implementing
  `on_menu_reply/3`. Its `cast/4` stages the offer on `PlayerState`'s
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
  Acts on the id the client picked from this skill's menu.

  `level` is the level of the cast that opened the menu, carried through the
  offer. The reply has already been validated as one of the offered ids, so an
  implementation may trust `selected_id`; a cancel never reaches here.
  """
  @callback on_menu_reply(PlayerState.t(), non_neg_integer(), pos_integer()) ::
              {:ok, PlayerState.t()} | {:error, atom()}
end
