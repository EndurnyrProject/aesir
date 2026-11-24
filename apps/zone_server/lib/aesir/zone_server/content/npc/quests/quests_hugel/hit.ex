defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Hit do
  @moduledoc """
  Marks the location of the attack effect.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "moc_fild12", x: 160, y: 372, dir: 0, sprite: 139, name: "Hit", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
