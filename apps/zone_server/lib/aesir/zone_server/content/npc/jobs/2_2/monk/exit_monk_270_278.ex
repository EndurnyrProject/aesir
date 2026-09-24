defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.ExitMonk270278 do
  @moduledoc """
  Congratulates a Monk candidate who reaches the end of a spirit maze and sends them back.

  ## Behavior

  - Marks the maze trial as cleared and tells the candidate to return to Tomoon.
  - Clears the monsters of this maze wing before warping the candidate out.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 270,
        y: 278,
        dir: 0,
        sprite: 45,
        name: "exit_monk",
        scope: :shared,
        unique_name: "exit_monk#3",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> mes("[Proctor]")
    |> mes("You did well. Please return to Tomoon, he's waiting for you.")
    |> set_char_var(:MONK_Q, 27)
    |> donpcevent("mob_monk#3_5::OnDisable")
    |> donpcevent("mob_monk#3_4::OnDisable")
    |> donpcevent("mob_monk#3_3::OnDisable")
    |> donpcevent("mob_monk#3_2::OnDisable")
    |> donpcevent("mob_monk#3_1::OnDisable")
    |> close()
    |> warp("prt_monk", 196, 168)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
