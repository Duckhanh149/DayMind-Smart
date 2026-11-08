export class RevisionConflict extends Error {
  constructor() { super('Dữ liệu vừa thay đổi ở một tab khác. DayMind đã tải lại dữ liệu; hãy thực hiện lại thao tác.'); }
}
export function openStore(factory = indexedDB, name = 'daymind-local-v1') {
  return new Promise((resolve, reject) => {
    const request = factory.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('snapshots');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('Hãy đóng các tab DayMind cũ và thử lại.'));
  });
}
export function loadSnapshot(store) {
  return new Promise((resolve, reject) => {
    const tx = store.transaction('snapshots', 'readonly');
    const request = tx.objectStore('snapshots').get('main');
    tx.oncomplete = () => resolve(request.result || null);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error || new Error('Không thể đọc dữ liệu cục bộ.'));
  });
}
export function saveSnapshot(store, bytes, expectedRevision) {
  return new Promise((resolve, reject) => {
    const tx = store.transaction('snapshots', 'readwrite');
    const objectStore = tx.objectStore('snapshots');
    const request = objectStore.get('main');
    let conflict = false;
    request.onsuccess = () => {
      if ((request.result?.revision || 0) !== expectedRevision) { conflict = true; tx.abort(); return; }
      objectStore.put({ bytes, revision: expectedRevision + 1 }, 'main');
    };
    tx.oncomplete = () => resolve(expectedRevision + 1);
    tx.onabort = () => reject(conflict ? new RevisionConflict() : (tx.error || new Error('Không thể lưu dữ liệu trên thiết bị.')));
    tx.onerror = () => {}; // onabort owns rejection; never resolve before durable transaction completion.
  });
}
