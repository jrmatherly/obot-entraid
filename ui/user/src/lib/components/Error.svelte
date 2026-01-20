<script lang="ts">
	import { fade } from 'svelte/transition';
	import { parseErrorContent } from '$lib/errors';

	interface Props {
		onClick?: (() => void) | null;
		error: Error;
	}

	let { onClick = null, error }: Props = $props();

	// Parse error content to extract status code and categorize
	const errorContent = $derived(parseErrorContent(error));
	const isClientError = $derived(errorContent.status >= 400 && errorContent.status < 500);
	const isServerError = $derived(errorContent.status >= 500);
</script>

<!--error component-->
<div in:fade class="flex items-center justify-center">
	<div class="text-center">
		<h3 class="text-on-background text-2xl font-semibold">Error</h3>
		<p class="text-on-surface1">{error.message}</p>
		{#if onClick}
			<button class="text-on-background mt-4 hover:underline" onclick={onClick}>Try again</button>
		{/if}
	</div>
</div>
