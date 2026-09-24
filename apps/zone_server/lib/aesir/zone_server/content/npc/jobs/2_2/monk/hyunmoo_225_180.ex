defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Hyunmoo225180 do
  @moduledoc """
  Abbey gardener who talks about gardening and reminds candidates of their next Monk test.

  ## Behavior

  - Tells Acolytes who passed the mushroom test to go meet Tomoon.
  - Shares thoughts on gardening with everyone else.

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
        map: "prt_monk",
        x: 225,
        y: 180,
        dir: 1,
        sprite: 89,
        name: "Hyunmoo",
        scope: :shared,
        unique_name: "Hyunmoo#mk2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest < 25 ->
        talk_about_gardening(ctx)

      quest > 24 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        ctx
        |> mes("[Hyunmoo]")
        |> mes("Didn't I tell you to go meet Tomoon? Or do you want to pick more mushrooms?")
        |> mes("Tomoon is staying in the deepest room inside a building near this abbey.")
        |> close()

      true ->
        talk_about_gardening(ctx)
    end
  end

  defp talk_about_gardening(ctx) do
    ctx
    |> mes("[Hyunmoo]")
    |> mes("As I see vegetables growing, I feel myself growing within.")
    |> next()
    |> mes("[Hyunmoo]")
    |> mes("As I see other monks working hard on growing vegetables,")
    |> mes("it warms my heart to see others enjoying gardening as I do.")
    |> next()
    |> mes("[Hyunmoo]")
    |> mes("To be honest with you, I think gardening is the greatest thing ever...")
    |> mes(
      "We should give thanks to the brothers who prepare our food for us through their hard work."
    )
    |> next()
    |> mes("[Hyunmoo]")
    |> mes("Don't forget to thank them as you go by for their hard work.")
    |> close()
  end
end
